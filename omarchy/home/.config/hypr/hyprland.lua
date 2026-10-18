-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/
-- Omarchy 既定の hyprland.lua をベースに、既定 binding を全無効化したもの(dotfiles 管理)。

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Omarchy は「ドライバ等の整った環境」として使い、見た目と操作は持ち込まない。
-- そのため require("default.hypr.omarchy") は使わず、そこから
--   - 既定 binding(Super+文字 が xremap の Emacs 風移動とぶつかる。hypr/bindings.lua で最小限張り直す)
--   - looknfeel / テーマ色(Hyprland 本来の初期値に戻す。必要な挙動だけ hypr/looknfeel.lua に移した)
-- を除いたものだけ読む。Omarchy 更新で default/hypr/omarchy.lua に追加があればここにも足すこと。
require("default.hypr.helpers")
require("default.hypr.autostart")
require("default.hypr.envs")
require("default.hypr.input")
require("default.hypr.windows")

-- windows.lua が全ウィンドウに付ける既定の半透明(default-opacity)を打ち消す
o.window({ tag = "default-opacity" }, { opacity = "1 1" })

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Toggle config flags dynamically.
require("default.hypr.toggles")
