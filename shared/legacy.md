# Legacy CLI をソースから導入する

`setup.sh` は `shared/installers/legacy.sh` で CLI 本体をビルドし、
`lib/link-bin.sh` で `~/.local/bin/legacy` を配置する。
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
このコミットはリモート main へ未反映で、今回は push していない。
新しい Mac で利用する前に、ソースを正式な参照から取得可能にする作業が別途必要。
削除済みブランチのコミットが GitHub 内部に保持されていることには依存しない。

## 新規 Mac の導入順序（対応が残る点）

基本セットアップで Git・Rust・1Password CLI 等を用意し、次に `synpuls/bootstrap` で
SSH 設定・鍵を配置し、その後に CLI インストーラーを実行する必要がある。
現在は基本の `setup.sh` からも CLI を呼んでおり、鍵が未配置だと取得に失敗する。
この呼び出しを切り離す変更は未実施。以下は SSH 認証が準備済みの場合の手順。

## 導入・更新

通常は `./setup.sh`。CLI だけなら次を実行する。

```sh
./shared/installers/legacy.sh
./lib/link-bin.sh
```

インストーラーは Cargo に固定 commit と `--locked` を渡す。
既存 checkout を書き換えず、一時領域で CLI パッケージだけをビルドする。
Souther コンパイラーや Postgres、Node.js はこのビルドには不要。

commit・Rust 版・OS/CPU が同じで、導入済みバイナリの版を確認できれば再ビルドしない。
更新は固定値を変更して再実行する。ビルドと起動確認に成功した後だけ
`~/.local/opt/legacy/bin/legacy` のリンクを切り替え、失敗時は以前の版を残す。
CLI 導入に失敗しても、`setup.sh` は他の設定処理を続け、最後に非ゼロで終了する。

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

## 確認済みの範囲

Linux x86_64 で、空の導入先から固定コミットを取得し、本物の CLI をビルド・配置した。
再実行で取得もビルドも行わないこと、MCP 初期化・ツール一覧、ローカル API への読取接続を確認した。
テストでは版更新・ビルド失敗時の保持・セットアップの成功と失敗・ラッパーの引数と入出力を確認する。

```sh
python3 -m unittest discover -s tests -p 'test_legacy_install.py' -v
```

この方式での Mac ネイティブビルド・新規導入は未検証。
OS 名を置き換えたテストの成功を Mac 実機での検証済みとは扱わない。
