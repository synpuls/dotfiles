# Legacy CLI をソースから導入する

`setup.sh` は基本設定と `~/.local/bin/legacy` の起動用リンクを配置する。
SSH 設定後に `shared/installers/legacy.sh` を実行して CLI 本体をビルドする。
CLI の起動時には取得・ビルドしない。GitHub Actions・Releases・`gh` 認証は使わない。

## 前提と固定値

Git、rustup、C/C++ リンカーが必要。Mac は既存の Homebrew・`languages.sh` による
Rust 導入と Command Line Tools を使う。Linux は Rust とビルドツールを先に用意する。
必要な Rust の固定版が未導入ならインストーラーが rustup で導入する。
依存パッケージとツールチェーンの初回取得にはネットワーク接続が必要。

`shared/legacy-source.env` に Git URL・commit・Rust 版・CLI 版を固定する。
既定の URL は SSH ホスト名 `github-synpuls` を使う。既存の SSH 設定と鍵で
対象リポジトリを読めることが前提で、GitHub API の token は不要。

固定コミットは `6927624d87a9a4686de4cab680310bebc2b8d11e`。
このコミットを含むソースは private リポジトリの main で管理する。
新しい Mac は SSH 認証を準備したうえで、インストーラーから固定コミットを取得する。

## 初回の導入順序

1. dotfiles の `init.sh` → `setup.sh` で Git・Rust・1Password CLI 等と起動用リンクを用意する。
2. `synpuls/bootstrap` の `install.sh` で SSH 設定・鍵を配置する。
3. dotfiles のディレクトリに戻り、CLI を導入する。

```sh
./shared/installers/legacy.sh
legacy --version
```

基本の `setup.sh` は CLI のソース取得・ビルドを行わない。
SSH 設定後でも、ビルド対象の固定コミットを取得できることが必要。

## 更新

固定値を変更して `./shared/installers/legacy.sh` を再実行する。
通常の更新で基本セットアップや bootstrap をやり直す必要はない。

インストーラーは Cargo に固定 commit と `--locked` を渡す。
既存 checkout を書き換えず、一時領域で CLI パッケージだけをビルドする。
Souther コンパイラーや Postgres、Node.js はこのビルドには不要。

commit・Rust 版・OS/CPU が同じで、導入済みバイナリの版を確認できれば再ビルドしない。
更新は固定値を変更して再実行する。ビルドと起動確認に成功した後だけ
`~/.local/opt/legacy/bin/legacy` のリンクを切り替え、失敗時は以前の版を残す。
取得・ビルドに失敗した場合は、CLI インストーラーが非ゼロで終了する。

ローカルの Git リポジトリでも、同じ commit の取得・ビルド経路を検証できる。
手編集した未コミットファイルや、既存のビルド済みバイナリは使わない。

```sh
./shared/installers/legacy.sh --source file:///absolute/path/to/legacy --prefix /tmp/legacy-check
```

`--source` は取得先だけを変え、固定 commit は変えない。
`--prefix` は検証用の導入先。通常利用では既定の導入先を使う。

## 利用

```sh
export LEGACY_API_URL=https://your-legacy-server
legacy capabilities --json
legacy pages search --q '資料' --json
legacy mcp
```

認証が必要なら `LEGACY_API_TOKEN` を環境変数で渡す。
開発中に別のバイナリを起動する場合だけ `LEGACY_CLI_BINARY` で上書きできる。

## Codex から MCP を使う

CLI 導入後、dotfiles のディレクトリで登録を反映する（Python 3.11 以上）。

```sh
python3 lib/link-mcp.py
codex mcp get legacy
```

Codex を再起動すると Legacy の MCP ツールを利用できる。
`mcp.toml` の `[codex]` に登録しており、接続先は
`https://legacy.home.synpuls.digital`。
Codex が `~/.local/bin/legacy mcp` を起動し、stdio で通信する。
Legacy が HTTPS で本番 API に接続するため、手動で MCP プロセスを起動する必要はない。
Mac と Linux のホームディレクトリの違いは、起動時に `$HOME` を展開して扱う。

初回は「Legacy の MCP でページを検索して。変更はしないで」と依頼して確認できる。
既に同名の MCP を手動登録している場合、`link-mcp.py` は上書きしない。
`codex mcp get legacy` で設定を確認し、置き換える場合は
`codex mcp remove legacy` の後に登録を反映する。

## 確認済みの範囲

Linux x86_64 で、空の導入先から固定コミットを取得し、本物の CLI をビルド・配置した。
再実行で取得もビルドも行わないこと、MCP 初期化・ツール一覧、ローカル API への読取接続を確認した。
テストでは版更新・ビルド失敗時の保持・基本セットアップがCLI導入を呼ばないこと・ラッパーの引数と入出力を確認する。

```sh
python3 -m unittest discover -s tests -p 'test_legacy_install.py' -v
```

この方式での Mac ネイティブビルド・新規導入は未検証。
OS 名を置き換えたテストの成功を Mac 実機での検証済みとは扱わない。
