#!/usr/bin/env python3
"""skills.toml の宣言どおりに、各エージェントの skill ディレクトリへ symlink を張る。

マニフェスト（skills.toml = commit 必須 / skills.local.toml = gitignore 任意, 両方 union）:
  [skills.<name>]  取得元（どちらか一方）
     source = "owner/repo[/dir]"  … GitHub repo（dir 省略 = repo 直下）。毎回最新に追従
     path   = "dir"               … dotfiles 内の実体（shared/skills/ か skills.local/ 配下）
  [all]         skills=[]  Codex + 個人 Claude
  [codex]       skills=[]  Codex だけ        (~/.agents/skills)
  [claude]      skills=[]  個人 Claude だけ  (~/.claude/skills)
  [claude-work] skills=[]  会社 Claude だけ  (~/.claude-work/skills)

仕組み:
  source の repo は ~/.local/share/dotfiles-skills/<owner>__<repo> に repo 丸ごと shallow clone し、
  実行のたびに fetch + reset --hard で最新にする（楽観的追従。取得に失敗したら既存 checkout を使う）。
  repo 丸ごとなのは、skill が repo 内の兄弟ディレクトリを相対参照することがあるため。
  各 location の <name> は store か dotfiles 内の実体を指す symlink にする（実体はコピーしない）。

所有権: 「store / shared/skills / skills.local を直接指す symlink」をこのスクリプトの物とみなす。
  自分の物は張り替え・撤去し、それ以外の同名 entry（手置き）は触らず失敗として報告する。

失敗が 1 つでもあれば非ゼロで終了する（他の skill の配置は続ける）。
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:
    print("link-skills: python tomllib not available (need 3.11+)", file=sys.stderr)
    sys.exit(1)

ROOT_DIR = Path(__file__).resolve().parent.parent
HOME = Path.home()
STORE = HOME / ".local" / "share" / "dotfiles-skills"
GIT_BASE = "https://github.com"
LOCATIONS = {
    "codex": HOME / ".agents" / "skills",
    "claude": HOME / ".claude" / "skills",
    "claude-work": HOME / ".claude-work" / "skills",
}
SECTIONS = {"all": ["codex", "claude"], "codex": ["codex"], "claude": ["claude"],
            "claude-work": ["claude-work"]}
PATH_ROOTS = [ROOT_DIR / "shared" / "skills", ROOT_DIR / "skills.local"]
# 旧実装（npx 版）の state。あれば記載 entry を撤去して消す（全マシン移行後にこの処理ごと削除）
LEGACY_STATE = HOME / ".agents" / ".dotfiles-managed-skills.json"
LEGACY_LOCATIONS = {"agents": "codex", "claude": "claude", "claude-work": "claude-work"}

NAME_RE = re.compile(r"^[A-Za-z0-9_-][A-Za-z0-9._-]*$")
SOURCE_RE = re.compile(r"^([A-Za-z0-9-]+)/([A-Za-z0-9._-]+)(?:/(.+))?$")


def info(msg):
    print(f"link-skills: {msg}")


def warn(msg):
    print(f"link-skills: {msg}", file=sys.stderr)


def die(msg):
    warn(msg)
    sys.exit(1)


def inside(path, root):
    return path == root or root in path.parents


def load_manifests(paths):
    """マニフェストを検証して {name: spec} と {location: set(name)} を返す。"""
    specs, desired, refs = {}, {loc: set() for loc in LOCATIONS}, []
    for path in paths:
        try:
            data = tomllib.loads(path.read_text())
        except tomllib.TOMLDecodeError as e:
            die(f"invalid manifest {path}: {e}")
        if set(data) - {"skills", *SECTIONS}:
            die(f"unknown section {sorted(set(data) - {'skills', *SECTIONS})} ({path})")
        for name, entry in (data.get("skills") or {}).items():
            if not NAME_RE.match(name):
                die(f"invalid skill name [skills.{name}] ({path})")
            if len(entry) != 1 or set(entry) - {"source", "path"}:
                die(f"[skills.{name}] needs exactly one of source/path ({path})")
            if "source" in entry:
                m = SOURCE_RE.match(entry["source"])
                if not m or any(p in ("", ".", "..") for p in (m.group(3) or "x").split("/")):
                    die(f"[skills.{name}] invalid source {entry['source']!r} ({path})")
                specs[name] = {"repo": (m.group(1), m.group(2)), "dir": m.group(3) or ""}
            else:
                target = (ROOT_DIR / entry["path"]).resolve()
                if not any(root in target.parents for root in PATH_ROOTS):
                    die(f"[skills.{name}] path must be under shared/skills or skills.local ({path})")
                specs[name] = {"path": target}
        for section, locs in SECTIONS.items():
            sec = data.get(section) or {}
            if set(sec) - {"skills"} or not isinstance(sec.get("skills", []), list):
                die(f"[{section}] takes only skills = [...] ({path})")
            refs += [(section, name, locs) for name in sec.get("skills", [])]
    for section, name, locs in refs:
        if name not in specs:
            die(f"skill {name!r} in [{section}] but no [skills.{name}]")
        for loc in locs:
            desired[loc].add(name)
    return specs, desired


def migrate_legacy():
    """旧 state に載っている entry だけを撤去し、全部済んだら state を消す。"""
    if not LEGACY_STATE.exists():
        return
    data = json.loads(LEGACY_STATE.read_text())
    managed = data.get("managed")
    if data.get("version") != 2 or not isinstance(managed, dict) \
            or set(managed) - set(LEGACY_LOCATIONS) \
            or not all(isinstance(v, list) and all(NAME_RE.match(n) for n in v)
                       for v in managed.values()):
        die(f"unsupported legacy state {LEGACY_STATE}; inspect and remove it manually")
    for key, names in managed.items():
        for name in names:
            p = LOCATIONS[LEGACY_LOCATIONS[key]] / name
            if p.is_symlink() or p.is_file():
                p.unlink()
            elif p.is_dir():
                shutil.rmtree(p)
    LEGACY_STATE.unlink()
    info(f"migrated: removed entries listed in {LEGACY_STATE}")


def git(*args, cwd=None):
    env = {**os.environ, "GIT_TERMINAL_PROMPT": "0"}
    proc = subprocess.run(["git", *args], cwd=cwd, env=env, capture_output=True, text=True)
    return proc.returncode == 0, proc.stderr.strip()


def checkout_dir(repo):
    return STORE / "__".join(repo).lower()


def sync_repo(repo):
    """store の checkout を最新にする。成功なら True（失敗しても既存 checkout は残る）。"""
    d, slug = checkout_dir(repo), "/".join(repo)
    if not d.is_symlink() and (d / ".git").is_dir() and git("rev-parse", "HEAD", cwd=d)[0]:
        ok, err = git("fetch", "--depth", "1", "--no-tags", "origin", "HEAD", cwd=d)
        if ok:
            ok, err = git("reset", "--hard", "FETCH_HEAD", cwd=d)
        if not ok:
            warn(f"update {slug} failed; keep current checkout: {err}")
        return ok
    # 無い・壊れている → 一時ディレクトリに clone してから置き換える
    STORE.mkdir(parents=True, exist_ok=True)
    tmp = Path(tempfile.mkdtemp(prefix=f".{d.name}.", dir=STORE))
    try:
        ok, err = git("clone", "--depth", "1", "--no-tags", f"{GIT_BASE}/{slug}", str(tmp / "c"))
        if not ok:
            warn(f"clone {slug} failed: {err}")
            return False
        if d.is_symlink() or d.is_file():
            d.unlink()
        elif d.exists():
            shutil.rmtree(d)
        (tmp / "c").rename(d)
        info(f"cloned {slug}")
        return True
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def link_target(p):
    """symlink が直接指すパス（相対なら絶対化。最終到達先までは辿らない）。"""
    return Path(os.path.normpath(os.path.join(p.parent, os.readlink(p))))


def owned(p):
    return p.is_symlink() and any(inside(link_target(p), r) for r in [STORE, *PATH_ROOTS])


def place(dest, target):
    """dest -> target の symlink を用意する。手置きの同名 entry があれば False。"""
    if dest.is_symlink() and link_target(dest) == target:
        return True
    if owned(dest):
        dest.unlink()
    elif dest.exists() or dest.is_symlink():
        warn(f"skip {dest}: not managed by dotfiles (remove it to let dotfiles manage)")
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.symlink_to(target)
    info(f"link {dest} -> {target}")
    return True


def main():
    parser = argparse.ArgumentParser(description="skills.toml の宣言どおりに skill を配置する")
    parser.add_argument("--manifest", type=Path, help="このマニフェストだけを読む")
    args = parser.parse_args()
    manifests = [args.manifest or ROOT_DIR / "skills.toml"]
    if not manifests[0].is_file():
        die(f"manifest not found: {manifests[0]}")
    if not args.manifest and (ROOT_DIR / "skills.local.toml").is_file():
        manifests.append(ROOT_DIR / "skills.local.toml")
    specs, desired = load_manifests(manifests)
    migrate_legacy()
    used = set().union(*desired.values())
    failed = set()

    # 1) 宣言で使われている repo を最新にする
    synced = {r: sync_repo(r) for r in sorted({specs[n]["repo"] for n in used if "repo" in specs[n]})}

    # 2) 各 location に symlink を張る
    for name in sorted(used):
        spec = specs[name]
        if "repo" in spec:
            target = Path(os.path.normpath(checkout_dir(spec["repo"]) / spec["dir"]))
            if not synced[spec["repo"]]:
                failed.add(name)
        else:
            target = spec["path"]
        if not (target / "SKILL.md").is_file():
            warn(f"{name}: {target}/SKILL.md not found")
            failed.add(name)
            continue
        for loc, root in LOCATIONS.items():
            if name in desired[loc] and not place(root / name, target):
                failed.add(name)

    # 3) 宣言から外れた自分の symlink を外す（取得の成否ではなく宣言で判断する）
    for loc, root in LOCATIONS.items():
        for entry in sorted(root.iterdir()) if root.is_dir() else []:
            if owned(entry) and entry.name not in desired[loc]:
                entry.unlink()
                info(f"unlink {entry}")

    if failed:
        die(f"failed: {', '.join(sorted(failed))}")
    info("done")


if __name__ == "__main__":
    main()
