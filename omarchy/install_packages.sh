#!/bin/bash
# ユーザー層のツール導入（pacman/AUR は init.sh 済み）。
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "zplug"
if [ ! -d "$HOME/.zplug" ]; then
  curl -sL --proto-redir -all,https https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi

# fonts
"${SCRIPT_DIR}/fonts.sh"

########################## 日本語入力(fcitx5 + Hazkey) ##########################
# fcitx5 は omarchy-fcitx5.service が起動する。終了時に設定を書き戻すため、止めてから書く。
# profile/config は fcitx5 が置き換え保存するので symlink にはせず、未設定の時だけ生成する。
FCITX_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5"
# Hazkey(azooKey の変換エンジン。Mac のライブ変換と同じ自動変換ができる)を使う
if ! grep -qs '^Name=hazkey' "$FCITX_DIR/profile"; then
  echo "fcitx5 に Hazkey を設定します"
  systemctl --user stop omarchy-fcitx5.service || true
  pkill -x fcitx5 >/dev/null 2>&1 || true
  mkdir -p "$FCITX_DIR"
  cat >"$FCITX_DIR/profile" <<'PROFILE'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=hazkey

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=hazkey
Layout=

[GroupOrder]
0=Default
PROFILE
  # xremap が IME オフ/オンとして Muhenkan/Henkan を送る（Ubuntu の ibus-mozc 時代と同じキー）。
  # xremap は修飾キーと同時に送る(右 Alt → Alt+Henkan、左 Super → Ctrl/Super+Muhenkan)ので、
  # 修飾キー付きの組み合わせも登録する。
  cat >"$FCITX_DIR/config" <<'CONFIG'
[Hotkey]
EnumerateWithTriggerKeys=True
EnumerateSkipFirst=False

[Hotkey/TriggerKeys]
0=Control+space

[Hotkey/ActivateKeys]
0=Henkan_Mode
1=Alt+Henkan_Mode

[Hotkey/DeactivateKeys]
0=Muhenkan
1=Control+Muhenkan
2=Super+Muhenkan

[Behavior]
ShareInputState=All
# 切替時の「あ(Hiragana)」「en」ポップアップを出さない
ShowInputMethodInformation=False
ShowInputMethodInformationWhenFocusIn=False
CONFIG
  systemctl --user start omarchy-fcitx5.service
fi

########################## xremap ##########################
systemctl --user daemon-reload
systemctl --user enable xremap.service
systemctl --user restart xremap.service

########################## ssh-agent ##########################
systemctl --user enable --now ssh-agent.service

########################## Vicinae(ランチャー。Alt+F で開く) ##########################
systemctl --user enable --now vicinae.service

########################## 見た目(各ツール素の初期設定) ##########################
# Omarchy のテーマが配る GTK テーマ・アイコン・フォントを GNOME の初期値に戻し、ダークモードだけ有効にする。
# ※ `omarchy theme set` を実行すると再び上書きされる。
for key in icon-theme cursor-theme font-name monospace-font-name; do
  gsettings reset org.gnome.desktop.interface "$key"
done
gsettings set org.gnome.desktop.interface color-scheme prefer-dark # GTK4 / libadwaita
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark   # GTK3
gsettings set org.gnome.desktop.interface cursor-size 96         # hypr/looknfeel.lua の XCURSOR_SIZE と揃える

# 壁紙を描く Omarchy shell の background プラグインを無効化する(Hyprland の背景色だけになる)。
# shell.json は Omarchy のコマンドも書き換えるので link せず、該当キーだけ jq で足す。
SHELL_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/shell.json"
if [ -f "$SHELL_JSON" ] && ! jq -e '(.disabledPlugins // []) | index("omarchy.background")' "$SHELL_JSON" >/dev/null; then
  tmp="$(mktemp)"
  jq '.disabledPlugins = ((.disabledPlugins // []) + ["omarchy.background"])' "$SHELL_JSON" >"$tmp"
  mv "$tmp" "$SHELL_JSON"
fi

# バーの時計を秒まで出す自作版(plugins/synpuls.clock。1 秒ごとに更新)に差し替え、表示形式を秒付きにする
if [ -f "$SHELL_JSON" ] && jq -e '.. | objects | select(.id? == "omarchy.clock")' "$SHELL_JSON" >/dev/null; then
  tmp="$(mktemp)"
  jq '(.. | objects | select(.id? == "omarchy.clock") | .format) = "dddd HH:mm:ss"
    | (.. | objects | select(.id? == "omarchy.clock") | .id) = "synpuls.clock"
    | (if .bar.centerAnchor == "omarchy.clock" then .bar.centerAnchor = "synpuls.clock" else . end)' "$SHELL_JSON" >"$tmp"
  mv "$tmp" "$SHELL_JSON"
fi

# バーのワークスペース表示を 1・2 だけの自作版(plugins/synpuls.workspaces)に差し替える
if [ -f "$SHELL_JSON" ] && jq -e '.. | objects | select(.id? == "omarchy.workspaces")' "$SHELL_JSON" >/dev/null; then
  tmp="$(mktemp)"
  jq '(.. | objects | select(.id? == "omarchy.workspaces") | .id) = "synpuls.workspaces"' "$SHELL_JSON" >"$tmp"
  mv "$tmp" "$SHELL_JSON"
fi
