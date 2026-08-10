local wezterm = require("wezterm")

-- herdr の場所は環境で異なる (macOS Homebrew, Linux は curl installer で ~/.local/bin 等)
-- のでフルパス決め打ちを避け、候補 PATH を前置してから PATH 経由で解決する。
local herdr_path = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:"
	.. (os.getenv("HOME") or "")
	.. "/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

local function shell(command)
	return wezterm.action_callback(function()
		wezterm.background_child_process({
			"/bin/sh",
			"-c",
			"PATH=" .. herdr_path .. ":$PATH; " .. command,
		})
	end)
end

-- herdr の操作は「prefix 列を端末へ送る」方式にする。こうすると herdr が
-- ローカルでも `herdr --remote`(thin client)でも、client がキー列を server へ
-- 転送して同じ action が発火する。以前の shell('herdr ...') 方式は Mac 上の
-- herdr CLI を叩くため、remote 時に Mac ローカル socket を叩いてしまい無効だった。
-- prefix = Ctrl+S = \019。config.toml の [keys] 定義に対応させる。
local PREFIX = "\019"
local function herdr_key(seq)
	return wezterm.action.SendString(PREFIX .. seq)
end

return {
	default_prog = { "/bin/sh", "-lc", "PATH=" .. herdr_path .. ":$PATH; exec herdr" },

	-- font
	font = wezterm.font_with_fallback({
		{ family = "HackGen Console NF", weight = "Regular" },
	}),
	font_size = 16.8,

	-- ime
	use_ime = true,

	-- window
	initial_rows = 100,
	initial_cols = 260,
	-- 大量出力時にscrollbackが際限なくメモリを保持するのを防ぐ。
	scrollback_lines = 10000,
	hide_tab_bar_if_only_one_tab = true,

	-- opacity
	window_background_opacity = 0.95,

	-- theme
	color_scheme = "zenbones_dark",

	-- tab bar
	use_fancy_tab_bar = false,
	colors = {
		background = "black",

		cursor_bg = "#c6c8d1",
		tab_bar = {
			background = "#1b1f2f",

			active_tab = {
				bg_color = "#444b71",
				fg_color = "#c6c8d1",
				intensity = "Normal",
				underline = "None",
				italic = false,
				strikethrough = false,
			},

			inactive_tab = {
				bg_color = "#282d3e",
				fg_color = "#c6c8d1",
				intensity = "Normal",
				underline = "None",
				italic = false,
				strikethrough = false,
			},

			new_tab = {
				bg_color = "#1b1f2f",
				fg_color = "#c6c8d1",
				italic = false,
			},
		},
	},

	-- key
	keys = {
		-- Ctrl+Tab / Ctrl+Shift+Tab = wezterm のタブ切替(wezterm が消費し herdr へ渡さない)。
		-- ※ herdr 側の cycle_pane(旧 ctrl+tab)は空にして pane 巡回を無効化している。
		{ key = "Tab", mods = "CTRL", action = wezterm.action.ActivateTabRelative(1) },
		{ key = "Tab", mods = "CTRL|SHIFT", action = wezterm.action.ActivateTabRelative(-1) },
		{ key = "w", mods = "CMD", action = wezterm.action.DisableDefaultAssignment },
		{ key = "q", mods = "CMD", action = wezterm.action.DisableDefaultAssignment },
		{ key = "LeftArrow", mods = "CTRL", action = wezterm.action.DisableDefaultAssignment },
		{ key = "RightArrow", mods = "CTRL", action = wezterm.action.DisableDefaultAssignment },
		{ key = "LeftArrow", mods = "CMD", action = wezterm.action.DisableDefaultAssignment },
		{ key = "RightArrow", mods = "CMD", action = wezterm.action.DisableDefaultAssignment },
		-- Cmd+S: nvim(AstroNvim) の <Esc><leader>w = Save を叩く。herdr を経由して
		-- pane(nvim) にそのまま渡る。reload-config は Cmd+R 側に集約。
		{ key = "s", mods = "CMD", action = wezterm.action.SendString("\027 w") },
		-- Cmd+R: herdr server reload-config。※ remote(herdr --remote)時は Mac 側 CLI を
		-- 叩くため VM の server には効かない。VM 側 config を reload したい時は VM の
		-- pane で `herdr server reload-config`(server の `r` alias)を使う。
		{ key = "r", mods = "CMD", action = shell("herdr server reload-config >/dev/null") },

		-- workspace の作成, 移動（prefix 列送出＝ローカル/リモート両対応）
		-- ※ 旧 shell 版の「wrap-around 移動」は herdr ネイティブ action(next|previous_workspace)へ置換。
		-- Cmd+Shift+T=「空の新規 workspace at $HOME」。new_cwd=follow だと native new_workspace が
		--    現 cwd を継承する(=複製に見える)ため、zsh widget(^X^T)で --cwd $HOME 明示作成する。
		{ key = "t", mods = "CMD|SHIFT", action = wezterm.action.SendString("\x18\x14") }, -- ^X^T = herdr-new-home-workspace
		{ key = "j", mods = "CMD", action = herdr_key("j") }, -- next_workspace
		{ key = "k", mods = "CMD", action = herdr_key("k") }, -- previous_workspace

		-- tab の作成, 移動
		{ key = "t", mods = "CMD", action = herdr_key("t") }, -- new_tab
		{ key = "h", mods = "CMD", action = herdr_key("h") }, -- previous_tab
		{ key = "l", mods = "CMD", action = herdr_key("l") }, -- next_tab

		-- kill
		-- ※ 旧 Cmd+W の「最後の tab なら workspace ごと閉じる」特別扱いは、herdr ネイティブ
		--    close_tab に置換（=単純に tab を閉じる）。close-ws-if-last が要る場合は要相談。
		{ key = "w", mods = "CMD", action = herdr_key("w") }, -- close_tab
	},
}
