# Legacy CLI の導入

`setup.sh` が CLI 本体を取得し、`lib/link-bin.sh` が `~/.local/bin/legacy` を配置する。
別途 Legacy のソースを checkout したり、Rust を導入したりする必要はない。
起動するたびに取得・ビルドする処理もない。

macOS の Apple Silicon / Intel、Linux の ARM64 / x86_64 に対応する配布物を選ぶ。
Linux は glibc 2.39 以降。Mac 版は deployment target 13.0、実行確認は macOS 15。
`shared/legacy-release.env` に固定した版と SHA-256 だけを使い、検証と起動に成功してから
インストール済みの版を切り替える。再度 setup した際、検証済みの版があれば取得しない。

## 初回配布は未完了

現在の `legacy-release.env` は未確定のため空欄である。このままの `setup.sh` では
Legacy を導入できない。他の設定処理は継続し、最後に CLI の未完了を表示して非ゼロで終了する。
初回の配布・実機検証が終わったと誤認させないため、成功扱いにはしない。

Legacy リポジトリの `.github/workflows/cli-release.yml` で 4 環境を検証し、
Cargo の版と一致する `cli-v<版>` タグで draft Release を作る。
検証結果を確認して Release を公開した後、その `legacy-release.env` をここへコピーし、
レビュー・commit する。架空のハッシュや `latest` を設定しない。
詳しい手順は Legacy リポジトリの `docs/cli-distribution.md` を参照する。

Release が private の場合、導入するマシンの `gh` をそのリポジトリへの read 権限で認証する。
public の場合は `curl` だけでも取得できる。チェックサムは Mac 標準の `shasum` でも検証できる。

## 利用

通常は dotfiles の `./setup.sh` を使う。CLI だけ導入・更新する場合:

```sh
./shared/installers/legacy.sh
./lib/link-bin.sh
```

接続先は利用するサーバーを指定する。秘密の token を dotfiles に書き込まない。

```sh
export LEGACY_API_URL=https://your-legacy-server
legacy capabilities --json
legacy pages search --q '資料' --json
legacy mcp
```

`legacy mcp` は標準入出力で coding agent と通信する。MCP 登録自体はこのインストーラーでは行わない。
開発中だけ別バイナリを使いたい場合は `LEGACY_CLI_BINARY=/absolute/path/to/legacy` で上書きできる。
通常の起動は `~/.local/opt/legacy/bin/legacy` を使う。

## 検証

```sh
python3 -m unittest discover -s tests -p 'test_legacy_install.py' -v
```

OS/CPU と配布サーバーを置き換え、実ファイルで選択・ハッシュ・起動・更新失敗時の保持を確認する。
GitHub からの実際のダウンロードやネイティブバイナリの Mac 起動まで確認したテストではない。
その確認は初回リリース時に別途行う。
