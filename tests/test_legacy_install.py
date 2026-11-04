"""Source installer contracts; the Rust build itself is also checked separately with the real CLI."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='legacy source ')
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.root = self.base / 'dotfiles'
        (self.root / 'shared/installers').mkdir(parents=True)
        shutil.copy2(ROOT / 'shared/installers/legacy.sh', self.root / 'shared/installers/legacy.sh')
        self.pin = self.root / 'shared/legacy-source.env'
        shutil.copy2(ROOT / 'shared/legacy-source.env', self.pin)
        self.prefix = self.base / 'installed'
        self.bin = self.base / 'commands'
        self.bin.mkdir()
        self.log = self.base / 'build-log'
        self.env = dict(os.environ, PATH=f'{self.bin}:{os.environ["PATH"]}', BUILD_LOG=str(self.log))
        self.command('rustup', '''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ['BUILD_LOG'], 'a') as log:
    log.write(json.dumps({'args': args, 'cwd': os.getcwd(),
                         'git_cli': os.environ.get('CARGO_NET_GIT_FETCH_WITH_CLI'),
                         'target': os.environ.get('CARGO_TARGET_DIR')}) + '\\n')
if args[:2] == ['toolchain', 'install']:
    sys.exit(0)
if args[2:4] == ['rustc', '--version']:
    sys.exit(int(os.environ.get('MISSING_TOOLCHAIN', '0')))
assert args[2:4] == ['cargo', 'install']
assert '--locked' in args
assert args[args.index('--bin') + 1] == 'legacy'
assert args[-1] == 'legacy-client'
if os.environ.get('FAIL_BUILD') == '1':
    sys.exit(42)
root = pathlib.Path(args[args.index('--root') + 1]) / 'bin'
root.mkdir(parents=True)
binary = root / 'legacy'
binary.write_text('#!/bin/bash\\nprintf "legacy ' + os.environ.get('BUILD_VERSION', '0.1.0') + '\\\\n"\\n')
binary.chmod(0o755)
''')

    def command(self, name, content):
        path = self.bin / name
        path.write_text(content)
        path.chmod(0o755)

    def install(self):
        return subprocess.run(['bash', str(self.root / 'shared/installers/legacy.sh'),
                               '--prefix', str(self.prefix), '--source', 'file:///reviewed-source'],
                              env=self.env, cwd=self.base, capture_output=True, text=True, timeout=15)

    def success(self):
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        return (self.prefix / 'bin/legacy').resolve()

    def change_revision(self):
        old = '6927624d87a9a4686de4cab680310bebc2b8d11e'
        self.pin.write_text(self.pin.read_text().replace(old, 'a' * 40))

    def test_builds_locked_revision_outside_callers_directory(self):
        binary = self.success()
        records = [json.loads(line) for line in self.log.read_text().splitlines()]
        build = records[-1]
        args = build['args']
        self.assertEqual(args[:2], ['run', '1.99.1'])
        self.assertEqual(args[args.index('--rev') + 1], '6927624d87a9a4686de4cab680310bebc2b8d11e')
        self.assertEqual(args[args.index('--git') + 1], 'file:///reviewed-source')
        self.assertEqual(build['git_cli'], 'true')
        self.assertNotEqual(Path(build['cwd']), self.base)
        self.assertTrue(Path(build['target']).is_relative_to(self.prefix))
        self.assertEqual(subprocess.check_output([binary], text=True), 'legacy 0.1.0\n')

    def test_same_revision_needs_no_fetch_or_build(self):
        binary = self.success()
        before = self.log.read_text()
        self.env['FAIL_BUILD'] = '1'
        self.assertEqual(self.success(), binary)
        self.assertEqual(self.log.read_text(), before)

    def test_revision_update_switches_after_success(self):
        old = self.success()
        self.change_revision()
        new = self.success()
        self.assertNotEqual(new, old)
        self.assertTrue(old.is_file())

    def test_build_failure_retains_previous_install(self):
        old = self.success()
        self.change_revision()
        self.env['FAIL_BUILD'] = '1'
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual((self.prefix / 'bin/legacy').resolve(), old)
        self.assertEqual(list(self.prefix.glob('.install.*')), [])

    def test_wrong_binary_version_does_not_replace_previous_install(self):
        old = self.success()
        self.change_revision()
        self.env['BUILD_VERSION'] = '9.0.0'
        self.assertNotEqual(self.install().returncode, 0)
        self.assertEqual((self.prefix / 'bin/legacy').resolve(), old)

    def test_missing_pinned_toolchain_is_installed(self):
        self.env['MISSING_TOOLCHAIN'] = '1'
        self.success()
        records = [json.loads(line)['args'] for line in self.log.read_text().splitlines()]
        self.assertIn(['toolchain', 'install', '1.99.1', '--profile', 'minimal'], records)

    def test_invalid_pin_fails_before_fetch(self):
        self.pin.write_text(self.pin.read_text().replace('6927624d87a9a4686de4cab680310bebc2b8d11e', 'main'))
        self.assertNotEqual(self.install().returncode, 0)
        self.assertFalse(self.log.exists())

    def test_macos_and_linux_install_paths(self):
        self.command('uname', '#!/bin/bash\ncase "$1" in -s) echo "$TEST_OS" ;; -m) echo "$TEST_ARCH" ;; esac\n')
        for system, arch in [('Darwin','arm64'), ('Darwin','x86_64'), ('Linux','aarch64'), ('Linux','x86_64')]:
            with self.subTest(system=system, arch=arch):
                self.env.update(TEST_OS=system, TEST_ARCH=arch)
                self.assertEqual(self.success().parent.name, f'{system}-{arch}')

    def test_setup_runs_other_settings_and_reports_build_status(self):
        root = self.base / 'setup'
        for directory in ['lib', 'shared/installers', 'server']:
            (root / directory).mkdir(parents=True)
        shutil.copy2(ROOT / 'setup.sh', root / 'setup.sh')
        (root / 'lib/common.sh').write_text('resolve_machine() { echo server; }\n')
        installer = root / 'shared/installers/legacy.sh'
        installer.write_text('#!/bin/bash\nexport PATH="$TEST_COMMAND_DIR:$PATH"\nexec bash "$TEST_INSTALLER" --prefix "$TEST_PREFIX" --source file:///reviewed-source\n')
        installer.chmod(0o755)
        log = self.base / 'setup-steps'
        self.env.update(FAIL_BUILD='1', TEST_INSTALLER=str(self.root / 'shared/installers/legacy.sh'),
                        TEST_PREFIX=str(self.prefix), TEST_COMMAND_DIR=str(self.bin), SETUP_LOG=str(log))
        for name in ['server/install_packages.sh', 'server/languages.sh', 'server/editor.sh', 'lib/link-bin.sh']:
            stub = root / name
            stub.write_text('#!/bin/bash\nprintf "%s\\n" "$0" >> "$SETUP_LOG"\n')
            stub.chmod(0o755)
        for name in ['link-skills.py', 'link-mcp.py']:
            (root / 'lib' / name).write_text('import os\nwith open(os.environ["SETUP_LOG"], "a") as log: log.write(__file__ + "\\n")\n')
        for fail in ['1', '0']:
            with self.subTest(build_failure=fail):
                self.env['FAIL_BUILD'] = fail
                log.write_text('')
                result = subprocess.run(['bash', str(root / 'setup.sh')], env=self.env,
                                        text=True, capture_output=True, timeout=15)
                self.assertEqual(result.returncode == 0, fail == '0', result.stderr)
                for name in ['install_packages.sh', 'languages.sh', 'editor.sh', 'link-bin.sh', 'link-skills.py', 'link-mcp.py']:
                    self.assertIn(name, log.read_text())
                self.assertEqual('お疲れ様でした' in result.stdout, fail == '0')

    def test_wrapper_preserves_streams_arguments_cwd_and_exit(self):
        self.command('fake-legacy', '''#!/bin/bash
[[ "$1" = import && "$2" = './資料 dump.json' ]] || exit 99
[[ . -ef "$EXPECTED_CWD" ]] || exit 98
cat
printf 'diagnostic\n' >&2
exit 23
''')
        self.env.update(LEGACY_CLI_BINARY=str(self.bin / 'fake-legacy'), EXPECTED_CWD=str(self.base))
        alias = self.base / 'cwd-alias'
        alias.symlink_to(self.base, target_is_directory=True)
        for cwd in [self.base, alias]:
            result = subprocess.run([str(ROOT / 'shared/bin/legacy'), 'import', './資料 dump.json'],
                                    env=self.env, cwd=cwd, input='jsonrpc\n', text=True,
                                    capture_output=True, timeout=15)
            self.assertEqual((result.returncode, result.stdout, result.stderr), (23, 'jsonrpc\n', 'diagnostic\n'))


if __name__ == '__main__':
    unittest.main()
