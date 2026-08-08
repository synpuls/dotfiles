# dotfiles

Mac / Ubuntu デスクトップ / Linux サーバーの設定を 1 つの規約で管理する。

## 構造

```
dotfiles/
├── init.sh            # ①下ごしらえ(link まで)
├── setup.sh           # ②本セットアップ
├── genlocal.sh        # *.local の生成
├── check.sh           # マシン規約の検査
├── lib/               # 内部実装
├── githooks/          # pre-commit(秘密の混入をブロック)
├── shared/
│   ├── home/          # 全マシン共通の $HOME ミラー
│   └── vscode/        # 展開先が特殊なため別枠
├── mac/
│   ├── home/          # マシン固有の $HOME ミラー(shared より優先)
│   └── *.sh           # マシン規約のスクリプト + データ
├── ubuntu-desktop/
└── server/
```

- `$HOME` に link されるのは各層の `home/` の中身だけ。`lib/link.sh` が shared → machine の順に張る(後勝ち)
- マシンディレクトリは「`home/` を持つトップレベルディレクトリ(shared 以外)」で、
  `init.sh` `install_packages.sh` `languages.sh` `editor.sh` を実装する(`./check.sh` で検査)
- マシン判定は `lib/common.sh` のみ。初回の `./init.sh <machine>` が `~/.config/dotfiles/machine` に保存し、以後はそれが正

## どこに何を書くか

| 内容 | 置き場 |
|---|---|
| 全マシン共通 | `shared/home/` |
| マシン種別ごと | `<machine>/home/` |
| そのマシンだけ・非公開 | 同じ場所にファイル名 `.local` で置く |

`*.local` は .gitignore と pre-commit フックで git の外に保たれ、link は普通のファイルと同じ扱い。

- `<machine>/home/.zshrc.local` — `.zshrc.common.zsh` の最後に source される
- `<machine>/home/.gitconfig.local` — `.gitconfig` の include で読まれる
- SSH 設定・鍵は `<machine>/home/.ssh/` に置き、このディレクトリ配下は git 管理しない

`*.local` の生成: `.zshrc.local` / `.gitconfig.local` などは `./genlocal.sh` が作る。任意の
ファイルは `./genlocal.sh <file>` で隣に `.local` を作れる(読み込む仕組みは公開側に書くこと)。
除外は各層の `.genlocalignore`。一覧: `git ls-files --others --ignored --exclude-standard | grep '\.local'`

## セットアップ

```sh
# Linux のみ
sudo apt update && sudo apt upgrade && sudo apt install -y git curl zsh

ghq get git@github.com:synpuls/dotfiles.git
cd ~/workspace/github.com/synpuls/dotfiles && ./init.sh
```

ubuntu-desktop は初回のみ `./init.sh ubuntu-desktop` で機種を明示し、mozc に `ubuntu-desktop/mozc.txt` を import して再起動。

SSH 鍵を用意し(ed25519 + パスフレーズ、`<machine>/home/.ssh/` 配下に置き chmod 600)、公開鍵を GitHub に登録したら:

```sh
ssh -T git@github.com   # Hi <user>! を確認
./setup.sh
```

server は `./init.sh` の後、**docker group と default shell(zsh)を反映するため一度 logout/login**
してから `./setup.sh` を実行する。

## server プロファイル

devcontainer を前提にした Linux server 用の構成。設計:

- **プロジェクトの言語 toolchain は各 repo の devcontainer が持つ**(ローカルでも CI/クラウドでも同一環境)。
  host には言語を積まず、**`dcx`(= devcontainer up/exec/shell の薄いラッパ)で container 内実行**する。
  例: `dcx up` → `dcx -- <test コマンド>` / `dcx shell`。devcontainer が無い repo では `dcx` は exit 2。
- **host は Node の control-plane のみ**(`@devcontainers/cli` / npx / mcp 用)。`server/languages.sh` は Node だけ。
- **host の nvim は汎用編集のみ**。project の LSP/formatter/test/build は container 側(= `dcx`)。
  そのため `SYNPULS_NVIM_PROFILE=host` を export する(設定側でこの値を見て Mason 自動導入等を抑止する想定)。
- ツール(node/neovim/herdr/lazygit/lazydocker/delta/ghq/starship)は **mise** が管理する。
  version は `server/home/.config/mise/config.toml` に固定し、`mise.lock` が backend/hash を pin する
  (更新は version を書き換え → `mise install` → commit)。mise 本体だけ `server/tools.env` に pin+sha し
  `server/installers/mise.sh`(+ `lib/install-release.sh`)が導入する。devcontainer CLI は npm(mise の node)。
  host に go/rust ツールチェーンは不要。
- **Docker は rootful + docker group**。docker group は実質 root 権限であることに留意。

## メモ

- nvim 設定は別リポジトリ([nvim-user-v6](https://github.com/synpuls/nvim-user-v6))。
  server は nvim 本体を **mise** で、設定を `server/editor.sh` が **commit 固定**で取得する(他マシンは `lib/nvim.sh`)。
- フォントはコミットせず `ubuntu-desktop/fonts.sh` が Release から取得する
- vscode の拡張一覧はマニフェスト。現状で固定し直すには `shared/vscode/install.sh --freeze`
