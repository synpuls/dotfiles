#!/usr/bin/env python3
"""skills.toml を望ましい状態として各エージェントの skill を収束させる reconciler。

宣言的: マニフェストを編集して再実行すれば install / uninstall / relink が揃う。

マニフェスト（skills.toml = commit / skills.local.toml = gitignore, 両方 union）:
  [skills.<name>]  取得元
     source = "owner/repo"   … npx skills add の引数
     skill  = "<name>"       … 複数 skill repo から 1 つ選ぶ(任意, npx の -s)
     path   = "dir"          … dotfiles 内の実体(上流の無い自作 skill 用, source と排他)
  [all]    skills=[]  両エージェントに配る
  [codex]  skills=[]  codex だけ
  [claude] skills=[]  claude だけ

配置（可視性）:
  Codex は ~/.agents/skills を、Claude は ~/.claude/skills を読む。
    all    → ~/.agents/skills に実体 + ~/.claude/skills から symlink
    codex  → ~/.agents/skills に実体のみ
    claude → ~/.claude/skills に実体のみ（~/.agents に置くと codex に漏れるため）

所有権: この reconciler が入れた skill(state file)だけを収束対象にし、手置き skill は
  触らない。npx への配置は -a codex / -a claude-code で分ける。
"""
import filecmp
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
    print("link-skills: python tomllib not available (need 3.11+); skip", file=sys.stderr)
    sys.exit(0)

ROOT_DIR = Path(__file__).resolve().parent.parent
HOME = Path.home()
AGENTS_SKILLS = HOME / ".agents" / "skills"
CLAUDE_SKILLS = HOME / ".claude" / "skills"
BACKUP_DIR = HOME / ".agents" / "skill-backups"
STATE_FILE = HOME / ".agents" / ".dotfiles-managed-skills.json"
NAME_RE = re.compile(r"^[A-Za-z0-9._-]+$")


def info(msg):
    print(f"link-skills: {msg}")


def warn(msg):
    print(f"link-skills: {msg}", file=sys.stderr)


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


def backup(path):
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    dest = Path(tempfile.mkdtemp(prefix=f"{path.name}.", dir=BACKUP_DIR))
    shutil.move(str(path), str(dest / path.name))
    return dest


def has_npx():
    return shutil.which("npx") is not None


def load_manifests(paths):
    """複数マニフェストを読み検証・union する。

    return (specs, codex_set, claude_set):
      specs      : {name: {"kind","source","skill"|"path"}}
      codex_set  : ~/.agents に置く skill = [all]+[codex]
      claude_set : ~/.claude に置く skill = [all]+[claude]
    """
    specs = {}
    buckets = {"all": [], "codex": [], "claude": []}
    for path in paths:
        if not path.is_file():
            continue
        try:
            data = tomllib.loads(path.read_text())
        except tomllib.TOMLDecodeError as e:
            die(f"invalid manifest {path}: {e}")
        for name, entry in (data.get("skills") or {}).items():
            if not NAME_RE.match(name):
                die(f"invalid skill name in [skills.{name}] ({path})")
            entry = entry or {}
            source, rel = entry.get("source"), entry.get("path")
            if bool(source) == bool(rel):
                die(f"[skills.{name}] must have exactly one of source/path ({path})")
            if source:
                specs[name] = {"kind": "source", "source": source, "skill": entry.get("skill")}
            else:
                specs[name] = {"kind": "path", "path": rel}
        for section in buckets:
            names = (data.get(section) or {}).get("skills", [])
            if not isinstance(names, list):
                die(f"[{section}].skills must be an array ({path})")
            buckets[section].extend(names)

    codex_set, claude_set = set(), set()
    for section, names in buckets.items():
        for name in names:
            if not NAME_RE.match(name):
                die(f"invalid skill name referenced: {name!r}")
            if name not in specs:
                die(f"skill {name!r} in [{section}] but no [skills.{name}]")
            if section in ("all", "codex"):
                codex_set.add(name)
            if section in ("all", "claude"):
                claude_set.add(name)
    return specs, codex_set, claude_set


def points_into_dotfiles(path):
    if not path.is_symlink():
        return False
    return ROOT_DIR == path.resolve() or ROOT_DIR in path.resolve().parents


def link_target(path):
    """symlink の 1 ホップ先を絶対パスに正規化（相対 symlink 対応）。"""
    raw = os.readlink(path)
    return Path(os.path.normpath(os.path.join(path.parent, raw)))


def npx_add(name, spec, agent):
    """source skill を指定 agent 向けに install。成功なら True。

    成功判定は SKILL.md の有無。PromptScript 型は非ゼロ終了でも本体は入る。
    """
    if not has_npx():
        warn(f"npx not found; cannot install {name}")
        return False
    cmd = ["npx", "--yes", "skills", "add", spec["source"], "-g", "-a", agent]
    if spec.get("skill"):
        cmd += ["-s", spec["skill"]]
    info(f"install {name} -> {agent}")
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    return True


def ensure_content(dest_root, name, spec, agent):
    """dest_root/<name> に実体を用意（source は npx、path は dotfiles への symlink）。"""
    dest = dest_root / name
    if (dest / "SKILL.md").is_file() and not (
        dest.is_symlink() and not points_into_dotfiles(dest)
    ):
        return True
    if spec["kind"] == "path":
        target = (ROOT_DIR / spec["path"]).resolve()
        if not (target / "SKILL.md").is_file():
            warn(f"path skill {name}: {target}/SKILL.md not found; skip")
            return False
        if dest.is_symlink() and dest.resolve() == target:
            return True
        dest_root.mkdir(parents=True, exist_ok=True)
        if dest.exists() or dest.is_symlink():
            backup(dest)
        dest.symlink_to(target)
        info(f"link {dest} -> {target}")
        return True
    # source 型
    npx_add(name, spec, agent)
    if not (dest / "SKILL.md").is_file():
        warn(f"install did not create {dest}/SKILL.md")
        return False
    return True


def ensure_claude_symlink(name):
    """[all] 用: ~/.claude/skills/<name> -> ~/.agents/skills/<name>。"""
    canon = AGENTS_SKILLS / name
    target = CLAUDE_SKILLS / name
    if not (canon / "SKILL.md").is_file():
        return
    if target.is_symlink() and target.resolve() == canon.resolve():
        return
    CLAUDE_SKILLS.mkdir(parents=True, exist_ok=True)
    if target.exists() or target.is_symlink():
        backup(target)
    target.symlink_to(canon)
    info(f"claude {target} -> {canon}")


def remove_entry(path, name):
    """指定 location の skill 実体だけを撤去する。

    npx skills remove はグローバルで他 location(別エージェント)も巻き込むため使わない。
    symlink は unlink、実体 dir は backup へ退避（filesystem 単位で per-location に閉じる）。
    npx の lock がずれても reconciler は lock を参照しないので実害はない。
    """
    if not (path.exists() or path.is_symlink()):
        return
    if path.is_symlink():
        path.unlink()
        info(f"unlink {path}")
    else:
        backup(path)
        info(f"remove {path}")


def main():
    if len(sys.argv) > 1:
        manifests = [Path(sys.argv[1])]
    else:
        manifests = [ROOT_DIR / "skills.toml", ROOT_DIR / "skills.local.toml"]
    specs, codex_set, claude_set = load_manifests(manifests)
    all_desired = codex_set | claude_set

    managed = set(load_json(STATE_FILE, {"managed": []}).get("managed") or [])

    # 1) ~/.agents（codex 可視）: [all]+[codex] の実体を用意
    for name in sorted(codex_set):
        if ensure_content(AGENTS_SKILLS, name, specs[name], "codex"):
            managed.add(name)

    # 2) ~/.claude（claude 可視）
    for name in sorted(claude_set):
        if name in codex_set:
            ensure_claude_symlink(name)          # [all]: canonical へ symlink
            managed.add(name)
        elif ensure_content(CLAUDE_SKILLS, name, specs[name], "claude-code"):
            managed.add(name)                    # [claude] 専用: 実体を直接

    # 3) prune: managed のうち各 location の desired から外れた物を撤去
    if AGENTS_SKILLS.is_dir():
        for entry in sorted(AGENTS_SKILLS.iterdir()):
            n = entry.name
            if n in managed and n not in codex_set:
                remove_entry(entry, n)
    if CLAUDE_SKILLS.is_dir():
        for entry in sorted(CLAUDE_SKILLS.iterdir()):
            n = entry.name
            if n in managed and n not in claude_set:
                # ~/.claude 側は symlink(all の残骸) か実体(claude 専用の残骸)
                remove_entry(entry, n)

    managed = {n for n in (managed | all_desired) if
               (AGENTS_SKILLS / n).exists() or (CLAUDE_SKILLS / n).exists()
               or (AGENTS_SKILLS / n).is_symlink() or (CLAUDE_SKILLS / n).is_symlink()}
    save_json(STATE_FILE, {"managed": sorted(managed)})
    info("done")


if __name__ == "__main__":
    main()
