"""Installer contracts. OS/CPU and download are faked; filesystem/hash/exec are real."""
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
KEYS = ['LINUX_X64', 'LINUX_ARM64', 'MACOS_X64', 'MACOS_ARM64']


class InstallerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='legacy install ')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.prefix = self.base / 'installed'
        self.manifest = self.base / 'release.env'
        self.fixture = self.base / 'asset'
        self.log = self.base / 'downloads'
        self.bin = self.base / 'commands'
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}',
                        FIXTURE=str(self.fixture), DOWNLOAD_LOG=str(self.log),
                        TEST_OS='Darwin', TEST_ARCH='arm64')
        self.command('uname', '''#!/bin/bash
case "$1" in -s) echo "$TEST_OS" ;; -m) echo "$TEST_ARCH" ;; *) exit 2 ;; esac
''')
        self.command('gh', '''#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$DOWNLOAD_LOG"
[[ "${FAIL_DOWNLOAD:-}" != 1 ]] || exit 1
asset= directory=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pattern) asset=$2; shift 2 ;;
    --dir) directory=$2; shift 2 ;;
    *) shift ;;
  esac
done
cp "$FIXTURE" "$directory/$asset"
''')
        # Never contact the real network from a test.
        self.command('curl', '#!/bin/bash\nexit 22\n')
        self.pin()

    def command(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def pin(self, version='1.2.3'):
        self.fixture.write_text(f'#!/bin/bash\nprintf "legacy {version}\\n"\n')
        digest = hashlib.sha256(self.fixture.read_bytes()).hexdigest()
        self.manifest.write_text(
            f'LEGACY_RELEASE_TAG=cli-v{version}\nLEGACY_VERSION={version}\n'
            f'LEGACY_SOURCE_COMMIT={"a" * 40}\n' +
            ''.join(f'LEGACY_{key}_SHA256={digest}\n' for key in KEYS))

    def install(self):
        return subprocess.run(['bash', str(ROOT / 'shared/installers/legacy.sh'),
                               '--prefix', str(self.prefix), '--release-file', str(self.manifest)],
                              env=self.env, capture_output=True, text=True, timeout=15)

    def require_success(self):
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        return (self.prefix / 'bin/legacy').resolve()

    def test_os_cpu_asset_selection(self):
        cases = [('Darwin', 'arm64', 'aarch64-apple-darwin'),
                 ('Darwin', 'x86_64', 'x86_64-apple-darwin'),
                 ('Linux', 'aarch64', 'aarch64-unknown-linux-gnu'),
                 ('Linux', 'x86_64', 'x86_64-unknown-linux-gnu')]
        for system, arch, target in cases:
            with self.subTest(system=system, arch=arch):
                self.env.update(TEST_OS=system, TEST_ARCH=arch)
                installed = self.require_success()
                self.assertEqual(installed.parent.name, target)
                self.assertIn(f'--pattern legacy-{target}', self.log.read_text())
                self.assertEqual(installed.read_bytes(), self.fixture.read_bytes())

    def test_public_download_works_when_gh_cannot_authenticate(self):
        self.env['FAIL_DOWNLOAD'] = '1'
        self.command('curl', '''#!/bin/bash
set -eu
while [[ $# -gt 0 ]]; do
  if [[ "$1" = -o ]]; then cp "$FIXTURE" "$2"; exit 0; fi
  shift
done
exit 1
''')
        self.require_success()

    def test_repeated_setup_is_offline(self):
        installed = self.require_success()
        before = self.log.read_text()
        self.env['FAIL_DOWNLOAD'] = '1'
        self.assertEqual(self.require_success(), installed)
        self.assertEqual(self.log.read_text(), before)

    def test_pinned_update_switches_after_verification(self):
        old = self.require_success()
        self.pin('1.2.4')
        new = self.require_success()
        self.assertNotEqual(old, new)
        self.assertTrue(old.is_file())
        self.assertEqual(subprocess.check_output([new], text=True), 'legacy 1.2.4\n')

    def test_corrupt_download_retains_old_version(self):
        old = self.require_success()
        self.pin('1.2.4')
        self.fixture.write_text('not the reviewed binary')
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual((self.prefix / 'bin/legacy').resolve(), old)
        self.assertEqual(list(self.prefix.glob('.install.*')), [])

    def test_download_failure_retains_old_version(self):
        old = self.require_success()
        self.pin('1.2.4')
        self.env['FAIL_DOWNLOAD'] = '1'
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual((self.prefix / 'bin/legacy').resolve(), old)

    def test_non_runnable_verified_asset_retains_old_version(self):
        old = self.require_success()
        self.pin('1.2.4')
        self.fixture.write_text('#!/bin/bash\nexit 126\n')
        digest = hashlib.sha256(self.fixture.read_bytes()).hexdigest()
        self.manifest.write_text(self.manifest.read_text().split('LEGACY_MACOS_ARM64_SHA256=')[0]
                                 + f'LEGACY_MACOS_ARM64_SHA256={digest}\n')
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual((self.prefix / 'bin/legacy').resolve(), old)

    def test_unpublished_or_missing_checksum_is_not_success(self):
        self.manifest.write_text('LEGACY_RELEASE_TAG=\nLEGACY_VERSION=\nLEGACY_SOURCE_COMMIT=\n')
        self.assertNotEqual(self.install().returncode, 0)
        self.pin()
        lines = self.manifest.read_text().splitlines()
        self.manifest.write_text('\n'.join(l for l in lines if not l.startswith('LEGACY_MACOS_ARM64_SHA256=')))
        self.assertNotEqual(self.install().returncode, 0)
        self.assertFalse(self.log.exists())

    def test_unsupported_platform_does_not_download(self):
        for system, arch in [('FreeBSD', 'amd64'), ('Linux', 'riscv64')]:
            self.env.update(TEST_OS=system, TEST_ARCH=arch)
            self.assertNotEqual(self.install().returncode, 0)
        self.assertFalse(self.log.exists())

    def test_macos_shasum_fallback(self):
        if not shutil.which('shasum'):
            self.skipTest('shasum is unavailable')
        script = '''source "$1"
command() {
  if [[ "$*" = '-v sha256sum' ]]; then return 1; fi
  builtin command "$@"
}
ir_verify_sha256 "$2" "$3"
'''
        sha = hashlib.sha256(self.fixture.read_bytes()).hexdigest()
        args = ['bash', '-c', script, 'test', str(ROOT / 'lib/install-release.sh'), str(self.fixture)]
        self.assertEqual(subprocess.run([*args, sha]).returncode, 0)
        self.assertNotEqual(subprocess.run([*args, '0' * 64]).returncode, 0)

    def test_failed_cli_install_does_not_stop_other_dotfiles_setup(self):
        # Run the real setup orchestration; replace unrelated machine provisioning.
        root = self.base / 'dotfiles'
        for directory in ['lib', 'shared/installers', 'server']:
            (root / directory).mkdir(parents=True, exist_ok=True)
        for name in ['setup.sh', 'shared/installers/legacy.sh', 'lib/install-release.sh']:
            shutil.copy2(ROOT / name, root / name)
        (root / 'shared/legacy-release.env').write_text(
            'LEGACY_RELEASE_TAG=\nLEGACY_VERSION=\nLEGACY_SOURCE_COMMIT=\n')
        (root / 'lib/common.sh').write_text('resolve_machine() { echo server; }\n')
        log = self.base / 'setup-steps'
        self.env['SETUP_LOG'] = str(log)
        for name in ['server/install_packages.sh', 'server/languages.sh',
                     'server/editor.sh', 'lib/link-bin.sh']:
            stub = root / name
            stub.write_text('#!/bin/bash\nprintf "%s\\n" "$0" >> "$SETUP_LOG"\n')
            stub.chmod(0o755)
        # Use actual Python for the two unrelated link steps.
        for name in ['link-skills.py', 'link-mcp.py']:
            (root / 'lib' / name).write_text(
                'import os\nfrom pathlib import Path\n'
                'with Path(os.environ["SETUP_LOG"]).open("a") as log: log.write(__file__ + "\\n")\n')
        result = subprocess.run(['bash', str(root / 'setup.sh')], env=self.env,
                                text=True, capture_output=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('配布版が未確定', result.stderr)
        steps = log.read_text()
        for name in ['install_packages.sh', 'languages.sh', 'editor.sh',
                     'link-bin.sh', 'link-skills.py', 'link-mcp.py']:
            self.assertIn(name, steps)
        self.assertNotIn('お疲れ様でした', result.stdout)

    def test_wrapper_preserves_streams_arguments_cwd_and_exit(self):
        self.command('fake-legacy', '''#!/bin/bash
[[ "$1" = import && "$2" = './資料 dump.json' ]] || exit 99
# macOS の /var -> /private/var など、表記が異なっても同じディレクトリなら保持されている。
[[ . -ef "$EXPECTED_CWD" ]] || exit 98
cat
printf 'diagnostic\n' >&2
exit 23
''')
        self.env.update(LEGACY_CLI_BINARY=str(self.bin / 'fake-legacy'), EXPECTED_CWD=str(self.base))
        alias = self.base / 'cwd-alias'
        alias.symlink_to(self.base, target_is_directory=True)
        for cwd in [self.base, alias]:
            with self.subTest(cwd=str(cwd)):
                result = subprocess.run([str(ROOT / 'shared/bin/legacy'), 'import', './資料 dump.json'],
                                        env=self.env, cwd=cwd, input='jsonrpc\n', text=True,
                                        capture_output=True, timeout=15)
                self.assertEqual((result.returncode, result.stdout, result.stderr),
                                 (23, 'jsonrpc\n', 'diagnostic\n'))


if __name__ == '__main__':
    unittest.main()
