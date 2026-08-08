#!/usr/bin/env python3
"""mcp.toml を望ましい状態として各エージェントの MCP サーバを収束させる reconciler。

宣言的: マニフェストを編集して再実行すれば add / remove が揃う。skills と同じ
[all]/[codex]/[claude] モデル。skill と違い共有 canonical は無く、各エージェントの
CLI(`codex mcp` / `claude mcp`)を叩いて登録・削除する。

マニフェスト（mcp.toml = commit / mcp.local.toml = gitignore, 両方 union）:
  [servers.<name>]  command="..."  args=[...]  env={KEY="v"}
  [all]/[codex]/[claude]  servers=[...]

所有権: この reconciler が登録したサーバ(state file)だけを収束対象にし、各エージェント
内蔵のサーバ(Codex の node_repl / computer-use 等)や手動追加分は触らない。
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    print("link-mcp: python tomllib not available (need 3.11+); skip", file=sys.stderr)
    sys.exit(0)

ROOT_DIR = Path(__file__).resolve().parent.parent
STATE_FILE = Path.home() / ".agents" / ".dotfiles-managed-mcp.json"
NAME_RE = re.compile(r"^[A-Za-z0-9._-]+$")

# エージェントごとの CLI 差分。scope はグローバル登録用。env フラグ名も異なる。
AGENTS = {
    "codex": {"bin": "codex", "scope": [], "env_flag": lambda k, v: ["--env", f"{k}={v}"]},
    "claude": {"bin": "claude", "scope": ["-s", "user"], "env_flag": lambda k, v: ["-e", f"{k}={v}"]},
}


def info(msg):
    print(f"link-mcp: {msg}")


def warn(msg):
    print(f"link-mcp: {msg}", file=sys.stderr)


def die(msg):
    warn(msg)
    sys.exit(1)


def load_json(path, default):
    try:
        return json.loads(Path(path).read_text())
    except Exception:
        return default


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def load_manifests(paths):
    """return (specs, codex_set, claude_set)."""
    specs = {}
    buckets = {"all": [], "codex": [], "claude": []}
    for path in paths:
        if not path.is_file():
            continue
        try:
            data = tomllib.loads(path.read_text())
        except tomllib.TOMLDecodeError as e:
            die(f"invalid manifest {path}: {e}")
        for name, entry in (data.get("servers") or {}).items():
            if not NAME_RE.match(name):
                die(f"invalid server name [servers.{name}] ({path})")
            entry = entry or {}
            command = entry.get("command")
            if not command or not isinstance(command, str):
                die(f"[servers.{name}] needs a string command ({path})")
            args = entry.get("args", [])
            env = entry.get("env", {})
            if not isinstance(args, list) or not all(isinstance(a, str) for a in args):
                die(f"[servers.{name}].args must be a string array ({path})")
            if not isinstance(env, dict):
                die(f"[servers.{name}].env must be a table ({path})")
            specs[name] = {"command": command, "args": [str(a) for a in args],
                           "env": {str(k): str(v) for k, v in env.items()}}
        for section in buckets:
            names = (data.get(section) or {}).get("servers", [])
            if not isinstance(names, list):
                die(f"[{section}].servers must be an array ({path})")
            buckets[section].extend(names)

    codex_set, claude_set = set(), set()
    for section, names in buckets.items():
        for name in names:
            if name not in specs:
                die(f"server {name!r} in [{section}] but no [servers.{name}]")
            if section in ("all", "codex"):
                codex_set.add(name)
            if section in ("all", "claude"):
                claude_set.add(name)
    return specs, codex_set, claude_set


def exists(agent, name):
    return subprocess.run([AGENTS[agent]["bin"], "mcp", "get", name],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def add(agent, name, spec):
    cfg = AGENTS[agent]
    cmd = [cfg["bin"], "mcp", "add", *cfg["scope"]]
    for k, v in spec["env"].items():
        cmd += cfg["env_flag"](k, v)
    cmd += [name, "--", spec["command"], *spec["args"]]
    info(f"add {name} -> {agent}")
    r = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if r.returncode != 0:
        warn(f"add failed {name} -> {agent}: {r.stderr.strip()}")
        return False
    return True


def remove(agent, name):
    cfg = AGENTS[agent]
    info(f"remove {name} <- {agent}")
    subprocess.run([cfg["bin"], "mcp", "remove", *cfg["scope"], name],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    if len(sys.argv) > 1:
        manifests = [Path(sys.argv[1])]
    else:
        manifests = [ROOT_DIR / "mcp.toml", ROOT_DIR / "mcp.local.toml"]
    specs, codex_set, claude_set = load_manifests(manifests)

    managed = set(load_json(STATE_FILE, {"managed": []}).get("managed") or [])

    for agent, target in (("codex", codex_set), ("claude", claude_set)):
        if not shutil.which(AGENTS[agent]["bin"]):
            info(f"{agent} CLI not found; skip")
            continue
        # 宣言済みで未登録なら add
        for name in sorted(target):
            if exists(agent, name) or add(agent, name, specs[name]):
                managed.add(name)
        # この reconciler 管理で宣言から外れた物を remove
        for name in sorted(managed - target):
            if exists(agent, name):
                remove(agent, name)

    save_json(STATE_FILE, {"managed": sorted(codex_set | claude_set)})
    info("done")


if __name__ == "__main__":
    main()
