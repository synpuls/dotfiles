# dotfiles

Mac / Ubuntu デスクトップ / Omarchy / Linux サーバーの設定を 1 つの規約で管理する。

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
├── omarchy/
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
  (※ **機微な git 名義は private companion が `~/.gitconfig.local` を上書き供給**する。下記「機微設定」節)
- SSH 設定・鍵は `<machine>/home/.ssh/` に置き、このディレクトリ配下は git 管理しない
  (※ **実 SSH 鍵・`~/.ssh/config.local` は private companion が 1Password から供給**する。同節)

> `.local` / `genlocal.sh` は **非機密のローカル上書き専用**。実鍵・git 名義・sops など機微な設定は
> dotfiles ではなく private companion(`synpuls/bootstrap`)が供給する(下記「機微設定」節)。

`*.local` の生成: `.zshrc.local` / `.gitconfig.local` などは `./genlocal.sh` が作る。任意の
ファイルは `./genlocal.sh <file>` で隣に `.local` を作れる(読み込む仕組みは公開側に書くこと)。
除外は各層の `.genlocalignore`。一覧: `git ls-files --others --ignored --exclude-standard | grep '\.local'`

## 機微設定(private companion = `synpuls/bootstrap`)

公開できない機微設定 — 実 SSH 鍵 / git 名義(`~/.gitconfig.local`・`~/.gitconfig-work.local`)/
`~/.ssh/config.local` / sops の age 鍵 — は **この public repo には置かない**。正本は **1Password**、
別の **private repo [`synpuls/bootstrap`]** が `install.sh` で `$HOME` に配置する
(repo が持つのは op:// 参照と生成レシピだけで、鍵の実体は入らない)。

- 上の `.local` / `genlocal.sh` は **非機密のローカル上書き専用**。
- 機微な `.gitconfig.local` / `.ssh` 系は **bootstrap が正**(`install.sh` が既存を退避して `$HOME` へ上書き配置)。
- 前提: 1Password CLI(`op`)にサインイン済みであること(私鍵取得時に承認が入る)。

→ 新マシンは **① dotfiles(`init.sh` → `setup.sh`) → ② `synpuls/bootstrap`(`install.sh`) → ③ dotfilesの`shared/installers/legacy.sh`** の順に実行する。CLIのソース取得はSSH設定後に行う。

## セットアップ

```sh
# Linux のみ
sudo apt update && sudo apt install -y git curl zsh

# 初回は HTTPS で clone(SSH 鍵はこの後で用意するため)。SSH 化は鍵設定後に remote を張り替える。
ghq get https://github.com/synpuls/dotfiles
cd ~/workspace/github.com/synpuls/dotfiles && ./init.sh
```

omarchy(Arch + Hyprland)は `./init.sh` で自動判定される。`init.sh` が `omarchy update` → pacman/AUR のパッケージ・
xremap 用の uinput・pkexec 認証の保持・default shell(zsh)を設定するので、**一度 logout/login してから `./setup.sh`**
(詳細は下「omarchy プロファイル」節)。

ubuntu-desktop は初回のみ `./init.sh ubuntu-desktop` で機種を明示し、mozc に `ubuntu-desktop/mozc.txt` を import して再起動。

基本セットアップを実行する。この段階では Legacy の private ソースを取得しない。

```sh
./setup.sh
```

続いて `synpuls/bootstrap` の `install.sh` で SSH 設定・鍵を配置する
(取得方法・前提は bootstrap の手順に従う。詳細は上「機微設定」節)。
その後、dotfiles のディレクトリに戻って CLI を導入する。

```sh
./shared/installers/legacy.sh
legacy --version
```

固定ソースの取得条件と現在の検証範囲は [Legacy CLI の導入](shared/legacy.md) を参照する。

### ZMM（Rust / Souther）

Mac の `brew bundle --global` は Rust、ffmpeg、Java（Souther のビルド用、25以上）、Maven を用意する。Java 17 / sbt は通常の ZMM 用依存から外した。すでに導入済みのパッケージや旧 Scala 配布物は削除しない。

```sh
ghq get https://github.com/synpuls/zmm
# 初回だけ、ZMM の docs/rust-migration.md に従って
# Rust 1.95.0 と Souther native compiler（固定コミット）を準備する。
./shared/installers/zmm.sh
zmm --version
```

既定の checkout は `~/workspace/github.com/synpuls/zmm`。別の配置や worktree は `--repo DIR`（または `ZMM_REPO`）で指定する。ビルド・配置・モデルのロード検証・旧コマンドの退避は ZMM の `scripts/install-local` に委譲し、dotfiles は実行用 wrapper を上書きしない。`setup.sh` ではリポジトリ取得やビルドを自動実行せず、上記コマンドで明示的に導入・更新する。checkout の更新は利用者が行う。

検証済みバイナリから切り替える場合は次のように実行する。この場合 Java / Maven / Rust は不要で、既存の `target/` や `build/` も更新しない。

```sh
./shared/installers/zmm.sh --from /path/to/target/release
```

`~/.local/bin/zmm` は `~/.local/lib/zmm/releases/` の実行ファイルを参照する。旧コマンドは `~/.local/lib/zmm/backups/` に保持され、配置先は `ZMM_BIN_DIR` / `ZMM_INSTALL_ROOT` で変更できる。ignore 対象の MP3・キャッシュ・DB・旧 `target/universal/stage/` を削除する処理はない。

server は `./init.sh` の後、**docker group と default shell(zsh)を反映するため一度 logout/login**
してから `./setup.sh` を実行する。

## Mac の Tailscale

公式 Standalone 版を `mac/home/.Brewfile` の `tailscale-app` cask で管理する。
新規セットアップでは `./setup.sh` がインストールする。`greedy: true` により、
アプリに自動更新機能があっても `brew bundle --global` 実行時の更新確認に含める。

手動インストール済みの Mac では、最初に同じ公式 `.pkg` を Homebrew 経由で
インストールして管理下に入れる。インストーラーが求める管理者認証を行う。

```sh
brew install --cask tailscale-app
```

以後、Tailscale だけを更新する場合:

```sh
brew update
brew upgrade --cask --greedy tailscale-app
tailscale version
```

バージョンは固定せず、Homebrew が配布する安定版を使う。日常の自動更新は
Tailscale アプリの設定で有効にする。tailnet へのログイン・ACL・認証情報は管理画面で扱う。

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
  (更新は `mise outdated --bump` → `mise upgrade --interactive --bump` → 差分を commit)。mise 本体だけ `server/tools.env` に pin+sha し
  `server/installers/mise.sh`(+ `lib/install-release.sh`)が導入する。devcontainer CLI は npm(mise の node)。
  host の go/rust/Souther と Souther 用 JDK 25 は個人 host 開発用(プロジェクトの言語は devcontainer 側)。
- **Docker は rootful + docker group**。docker group は実質 root 権限であることに留意。

## omarchy プロファイル

Omarchy は「ドライバ等が整った Arch」として使い、見た目と操作は持ち込まない構成。

- **ショートカット**: `hypr/hyprland.lua` は `default.hypr.omarchy` を読まず、binding と looknfeel・テーマ色を除いた部品だけを読む
  (Omarchy 更新で `default/hypr/omarchy.lua` に部品が増えたら追従すること)。`hypr/bindings.lua` に GNOME 寄りの最小限だけ張る
  (Super+文字 は xremap の Emacs 風移動に使うため避ける)。ランチャーは Vicinae(Alt+F)。
- **見た目**: Hyprland・ghostty・starship・GTK は各ツール素の初期設定(ダークモード、余白 0、アニメーション off、壁紙なし)。
  壁紙は shell.json の `disabledPlugins` で Omarchy の background プラグインを止めている。`omarchy theme set` は GTK 等を上書きするので使わない。
- **ワークスペース**: 1・2 の 2 つだけ。バー表示は自作の `omarchy/plugins/synpuls.workspaces`(`omarchy.workspaces` の clone)。
- **キー**: xremap(`xremap-hypr-bin`、user service)。日英切替は単独押しのみ(右 Alt=日本語 / 左 Cmd=英語)。
- **日本語入力**: fcitx5 + Hazkey(azooKey の変換エンジン)。`hazkey/config.json` で自動変換(ライブ変換)を常時、
  入力中の予測ポップアップは無効(Space で候補一覧)。fcitx5 の profile/config は fcitx5 が書き戻すため link せず、未設定時だけ生成する。
  ghostty だけ `GTK_IM_MODULE=fcitx`(systemd drop-in)で候補位置を合わせている。Claude Code の入力欄は Claude Code 側の制約で候補がずれる(Ctrl+G で $EDITOR に逃がす)。
- **SSH / 機微設定**: `~/.ssh/config` はこの repo、鍵と `config.local` は bootstrap。bootstrap の前に 1Password アプリにサインインし、
  設定 → 開発者 →「1Password CLI と連携」を有効にする。ssh-agent は openssh の user unit。
  `lib/link.sh` は実ファイルの `*.local`(bootstrap が置く `~/.gitconfig.local` 等)を上書きしない。
- **nvim**: 本体は Omarchy 同梱。`omarchy/editor.sh` が nvim-user-v6 を `~/workspace/synpuls/` に clone し、Omarchy の LazyVim を退避して link する。

## メモ

- nvim 設定は別リポジトリ([nvim-user-v6](https://github.com/synpuls/nvim-user-v6))。
  server は nvim 本体を **mise** で、設定を `server/editor.sh` が **commit 固定**で取得する(他マシンは `lib/nvim.sh`)。
- フォントはコミットせず `ubuntu-desktop/fonts.sh` が Release から取得する
- vscode の拡張一覧はマニフェスト。現状で固定し直すには `shared/vscode/install.sh --freeze`
