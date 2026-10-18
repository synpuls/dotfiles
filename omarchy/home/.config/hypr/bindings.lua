-- Omarchy の既定 binding は hyprland.lua で全部無効化している(omarchy_default_bindings = false)。
-- xremap が Super+文字 を Emacs 風移動に使うので、文字キーは避けて Ubuntu(GNOME) 時代の操作に寄せる。
-- 物理キーとの対応は xremap の設定次第(Kinesis では wezterm 以外で物理 Ctrl が Super になる)。
-- 一覧: omarchy menu keybindings --print

-- 音量・輝度などのハードウェアキーは Omarchy 既定のまま使う
require("default.hypr.bindings.media")

-- アプリ・メニュー
-- Omarchy の既定ターミナル(~/.config/xdg-terminals.list)を開く
o.bind("SUPER + RETURN", "Terminal", { omarchy = "terminal" })
o.bind("SUPER + SPACE", "Launcher", "omarchy-menu toggle")
-- Ubuntu の Ulauncher と同じ Alt+F で Vicinae(Raycast 風ランチャー)を開く
o.bind("ALT + F", "Vicinae", "vicinae toggle")
o.bind("SUPER + ESCAPE", "System menu", "omarchy-menu toggle system")
o.bind("XF86PowerOff", "Power menu", "omarchy-menu toggle system", { locked = true })
o.bind("SUPER + F1", "Keybindings", "omarchy-menu-keybindings")

-- GNOME と同じ: ロック / スクリーンショット / ウィンドウを閉じる
o.bind("SUPER + CTRL + Q", "Lock system", "omarchy-system-lock")
-- 内蔵キーボード(Lemur Pro)は 左 Alt+右 Alt+Q を同時に認識できない(ハードウェアの制限)ため L でもロックできるようにする
o.bind("SUPER + CTRL + L", "Lock system", "omarchy-system-lock")
o.bind("SHIFT + ALT + dollar", "Screenshot", "omarchy-capture-screenshot")
o.bind("PRINT", "Screenshot", "omarchy-capture-screenshot")
o.bind("ALT + F4", "Close window", hl.dsp.window.close())

-- アプリ切替(xremap が wezterm 以外で Ctrl+Tab と Super+Tab を入れ替える)
o.bind("SUPER + TAB", "Focus on next window", hl.dsp.window.cycle_next())
o.bind("SUPER + TAB", "Reveal active window on top", hl.dsp.window.bring_to_top())
o.bind("SUPER + SHIFT + TAB", "Focus on previous window", hl.dsp.window.cycle_next({ next = false }))
o.bind("SUPER + SHIFT + TAB", "Reveal active window on top", hl.dsp.window.bring_to_top())

-- ワークスペースは 1・2 の 2 つだけ(バー表示は omarchy/plugins/synpuls.workspaces)。
-- GNOME と同じ Super+PageUp/PageDown で行き来する(xremap が Super+←/→ をここへ寄せる)。
o.bind("SUPER + Page_Up", "Next workspace", hl.dsp.focus({ workspace = "2" }))
o.bind("SUPER + Page_Down", "Previous workspace", hl.dsp.focus({ workspace = "1" }))
o.bind("SUPER + SHIFT + Page_Up", "Move window to next workspace", hl.dsp.window.move({ workspace = "2" }))
o.bind("SUPER + SHIFT + Page_Down", "Move window to previous workspace", hl.dsp.window.move({ workspace = "1" }))
-- 1・2 は空でも消さない(input.lua の 3 本指スワイプは新規作成しない設定なので、無いと行き先が無くなる)
hl.workspace_rule({ workspace = "1", persistent = true })
hl.workspace_rule({ workspace = "2", persistent = true })
for workspace = 1, 2 do
  local key = "code:" .. tostring(workspace + 9)
  o.bind("SUPER + " .. key, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
  o.bind("SUPER + SHIFT + " .. key, "Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = tostring(workspace) }))
end

-- ウィンドウ操作(Super+↑/↓ は xremap が触らない)
o.bind("SUPER + UP", "Full width", hl.dsp.window.fullscreen({ mode = "maximized" }))
o.bind("SUPER + SHIFT + UP", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.bind("SUPER + DOWN", "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" }))
o.bind("SUPER + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
o.bind("SUPER + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })
