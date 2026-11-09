#!/usr/bin/env python3
"""Explicitly retrieve the Todo client token from 1Password; never run during MCP startup."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--reference', default='op://Personal/todo-manager-client/credential')
args = parser.parse_args()
try:
    result = subprocess.run(['op', 'read', args.reference], capture_output=True, text=True)
except OSError:
    raise SystemExit('todo: 1Password CLI (op) is required')
if result.returncode:
    raise SystemExit('todo: 1Password read failed; sign in and check the item reference')
token = result.stdout.rstrip('\n')
if len(token) < 32 or '\n' in token or '\r' in token:
    raise SystemExit('todo: invalid API token; existing configuration was preserved')
config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'todo-manager'
config.mkdir(mode=0o700, parents=True, exist_ok=True)
if config.is_symlink() or config.stat().st_uid != os.getuid():
    raise SystemExit('todo: config directory must be owned by the current user and not a symlink')
config.chmod(0o700)
target = config / 'token'
if target.is_symlink():
    raise SystemExit('todo: refusing to replace a symlink token')
fd, stage = tempfile.mkstemp(prefix='.token.', dir=config)
try:
    with os.fdopen(fd, 'w') as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(token + '\n')
    os.replace(stage, target)
finally:
    Path(stage).unlink(missing_ok=True)
print('todo: private API token installed; value not displayed')
