"""Check the dotfiles entry point with a real native ZMM release.

ZMM_TEST_REPO=/path/to/zmm ZMM_TEST_BUILT_DIR=/path/to/target/release \
  python3 tests/test_zmm_install.py
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

INSTALLER = Path(__file__).resolve().parents[1] / 'shared/installers/zmm.sh'


class InstallTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='zmm dotfiles ')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.command = self.bin / 'zmm'
        self.old = b'#!/bin/sh\necho old-command\n'
        self.command.write_bytes(self.old)
        self.command.chmod(0o755)
        self.env = dict(os.environ, ZMM_BIN_DIR=str(self.bin),
                        ZMM_INSTALL_ROOT=str(self.root / 'install'),
                        JAVA_HOME='/nonexistent-java')

    def run_installer(self, *args):
        return subprocess.run([str(INSTALLER), *args], cwd=self.root, env=self.env,
                              text=True, capture_output=True, timeout=30)

    def test_missing_option_value_keeps_command(self):
        result = self.run_installer('--repo')
        self.assertEqual(result.returncode, 2)
        self.assertEqual(self.command.read_bytes(), self.old)

    def test_scala_only_checkout_is_rejected(self):
        repo = self.root / 'scala checkout'
        repo.mkdir()
        (repo / 'build.sbt').write_text('')
        result = self.run_installer('--repo', str(repo))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Rust/Souther', result.stderr)
        self.assertEqual(self.command.read_bytes(), self.old)

    def test_real_native_install_and_failed_update(self):
        if not all(os.environ.get(k) for k in ('ZMM_TEST_REPO', 'ZMM_TEST_BUILT_DIR')):
            self.skipTest('Set ZMM_TEST_REPO and ZMM_TEST_BUILT_DIR for the real release check')
        repo = os.environ['ZMM_TEST_REPO']
        source = Path(os.environ['ZMM_TEST_BUILT_DIR']).resolve()
        # The source path may contain spaces; prebuilt installs need no Java.
        alias = self.root / 'native release'
        alias.symlink_to(source, target_is_directory=True)
        result = self.run_installer('--repo', repo, '--from', str(alias))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.command.is_symlink())
        self.assertEqual(self.command.read_bytes(), (source / 'zmm').read_bytes())
        self.assertEqual(subprocess.check_output([str(self.command), '--version']),
                         subprocess.check_output([str(source / 'zmm'), '--version']))
        backups = list((self.root / 'install/backups').glob('*/zmm'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_bytes(), self.old)
        release = self.command.resolve()
        broken = self.root / 'broken'
        broken.mkdir()
        shutil.copy2(source / 'zmm', broken / 'zmm')
        lib = 'libsouther.dylib' if os.uname().sysname == 'Darwin' else 'libsouther.so'
        (broken / lib).write_bytes(b'invalid library')
        rejected = self.run_installer('--repo', repo, '--from', str(broken))
        self.assertNotEqual(rejected.returncode, 0)
        self.assertEqual(self.command.resolve(), release)
        self.assertEqual(len(list((self.root / 'install/backups').glob('*/zmm'))), 1)


if __name__ == '__main__':
    unittest.main()
