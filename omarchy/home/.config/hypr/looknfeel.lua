-- 見た目は Hyprland 本来の初期値のまま(Omarchy の looknfeel は hyprland.lua で読んでいない)。
-- ここには Omarchy の looknfeel から、見た目以外の挙動として必要なものだけを移している。

hl.config({
  -- 余白・枠線なしで画面いっぱいに表示する
  general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 0,
  },

  dwindle = {
    preserve_split = true,
    force_split = 2,
  },

  master = {
    new_status = "master",
  },

  misc = {
    -- 壁紙なし(misc:background_color の黒一色)にするため、Hyprland 既定の壁紙・ロゴは出さない
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_scale_notification = true,
    focus_on_activate = true,
    anr_missed_pings = 3,
    on_focus_under_fullscreen = 1,
    initial_workspace_tracking = 0,
    -- Let a fresh shell re-acquire the session lock after the lock client
    -- died, so omarchy-restart-shell can recover the LOCK failsafe.
    allow_session_lock_restore = true,
  },

  cursor = {
    hide_on_key_press = true,
    warp_on_change_workspace = 1,
  },

  binds = {
    hide_special_on_workspace_change = true,
  },

  -- ウィンドウ・ワークスペースの動き(視差効果)は不要
  animations = {
    enabled = false,
  },
})

-- マウスポインターは Adwaita の最大サイズ(24/30/36/48/72/96 のうち 96)
hl.env("XCURSOR_SIZE", "96")
hl.env("HYPRCURSOR_SIZE", "96")
