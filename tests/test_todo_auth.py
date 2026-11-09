"""Check private atomic credential installation without contacting 1Password."""
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='todo auth ') as directory:
    base = Path(directory)
    tools = base / 'bin'; tools.mkdir()
    op = tools / 'op'
    op.write_text('#!/bin/sh\n[ "$OP_FAIL" != 1 ] || exit 1\nprintf "%s" "$OP_TEST_VALUE"\n')
    op.chmod(0o755)
    env = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ['PATH'],
               XDG_CONFIG_HOME=str(base / 'config'), OP_FAIL='0', OP_TEST_VALUE='test-only-' * 5)
    args = ['python3', str(root / 'shared/installers/todo-auth.py')]
    result = subprocess.run(args, env=env, text=True, capture_output=True)
    assert result.returncode == 0 and env['OP_TEST_VALUE'] not in result.stdout + result.stderr
    target = base / 'config/todo-manager/token'
    old = target.read_bytes()
    assert target.stat().st_mode & 0o777 == 0o600
    assert target.parent.stat().st_mode & 0o777 == 0o700
    for changes in ({'OP_FAIL': '1'}, {'OP_TEST_VALUE': 'short'}, {'OP_TEST_VALUE': 'x'*40 + '\nsecond-line'}):
        result = subprocess.run(args, env=dict(env, **changes), text=True, capture_output=True)
        assert result.returncode != 0 and target.read_bytes() == old
    outside = base / 'outside'; outside.write_text('untouched')
    target.unlink(); target.symlink_to(outside)
    result = subprocess.run(args, env=env, text=True, capture_output=True)
    assert result.returncode != 0 and outside.read_text() == 'untouched'
print('PASS private token installation, credential suppression, failed read/update preservation and symlink rejection')
