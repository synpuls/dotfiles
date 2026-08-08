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
		{ key = "Tab", mods = "CTRL", action = wezterm.action.DisableDefaultAssignment },
		{ key = "Tab", mods = "CTRL|SHIFT", action = wezterm.action.DisableDefaultAssignment },
		{ key = "w", mods = "CMD", action = wezterm.action.DisableDefaultAssignment },
		{ key = "q", mods = "CMD", action = wezterm.action.DisableDefaultAssignment },
		{ key = "LeftArrow", mods = "CTRL", action = wezterm.action.DisableDefaultAssignment },
		{ key = "RightArrow", mods = "CTRL", action = wezterm.action.DisableDefaultAssignment },
		{ key = "LeftArrow", mods = "CMD", action = wezterm.action.DisableDefaultAssignment },
		{ key = "RightArrow", mods = "CMD", action = wezterm.action.DisableDefaultAssignment },
		-- Cmd+S: nvim(AstroNvim) の <Esc><leader>w = Save を叩く。herdr を経由して
		-- pane(nvim) にそのまま渡る。reload-config は Cmd+R 側に集約。
		{ key = "s", mods = "CMD", action = wezterm.action.SendString("\027 w") },
		{ key = "r", mods = "CMD", action = shell("herdr server reload-config >/dev/null") },

		-- workspace の作成, 移動
		{ key = "t", mods = "CMD|SHIFT", action = shell('herdr workspace create --cwd "$HOME" --focus >/dev/null') },
		{
			key = "j",
			mods = "CMD",
			action = shell(
				'workspace_id=$(herdr workspace list | jq -r \'.result.workspaces as $workspaces | ($workspaces | map(select(.focused == true))[0].number | tonumber) as $n | ($workspaces | sort_by(.number | tonumber) | map(select((.number | tonumber) > $n)) | first // ($workspaces | sort_by(.number | tonumber) | first)).workspace_id // empty\'); [ -n "$workspace_id" ] && herdr workspace focus "$workspace_id" >/dev/null'
			),
		},
		{
			key = "k",
			mods = "CMD",
			action = shell(
				'workspace_id=$(herdr workspace list | jq -r \'.result.workspaces as $workspaces | ($workspaces | map(select(.focused == true))[0].number | tonumber) as $n | ($workspaces | sort_by(.number | tonumber) | map(select((.number | tonumber) < $n)) | last // ($workspaces | sort_by(.number | tonumber) | last)).workspace_id // empty\'); [ -n "$workspace_id" ] && herdr workspace focus "$workspace_id" >/dev/null'
			),
		},

		-- tab の作成, 移動
		{
			key = "t",
			mods = "CMD",
			action = shell(
				'workspace_id=$(herdr workspace list | jq -r \'.result.workspaces[] | select(.focused == true) | .workspace_id\' | head -n 1); [ -n "$workspace_id" ] && herdr tab create --workspace "$workspace_id" --focus >/dev/null'
			),
		},
		{
			key = "h",
			mods = "CMD",
			action = shell(
				'workspace_id=$(herdr workspace list | jq -r \'.result.workspaces[] | select(.focused == true) | .workspace_id\' | head -n 1); tab_id=$(herdr tab list --workspace "$workspace_id" | jq -r \'.result.tabs as $tabs | ($tabs | map(select(.focused == true))[0].number | tonumber) as $n | ($tabs | sort_by(.number | tonumber) | map(select((.number | tonumber) < $n)) | last // ($tabs | sort_by(.number | tonumber) | last)).tab_id // empty\'); [ -n "$tab_id" ] && herdr tab focus "$tab_id" >/dev/null'
			),
		},
		{
			key = "l",
			mods = "CMD",
			action = shell(
				'workspace_id=$(herdr workspace list | jq -r \'.result.workspaces[] | select(.focused == true) | .workspace_id\' | head -n 1); tab_id=$(herdr tab list --workspace "$workspace_id" | jq -r \'.result.tabs as $tabs | ($tabs | map(select(.focused == true))[0].number | tonumber) as $n | ($tabs | sort_by(.number | tonumber) | map(select((.number | tonumber) > $n)) | first // ($tabs | sort_by(.number | tonumber) | first)).tab_id // empty\'); [ -n "$tab_id" ] && herdr tab focus "$tab_id" >/dev/null'
			),
		},

		-- kill
		-- Cmd+W は tab close。ただし tab が最後の 1 つなら workspace ごと閉じる。
		-- tab_count が数値で取れない時は誤って workspace を消さず tab close に倒す。
		{
			key = "w",
			mods = "CMD",
			action = shell(
				'pane=$(herdr pane current); workspace_id=$(printf "%s" "$pane" | jq -r \'.result.pane.workspace_id // empty\'); tab_id=$(printf "%s" "$pane" | jq -r \'.result.pane.tab_id // empty\'); tab_count=$(herdr tab list --workspace "$workspace_id" | jq -r \'.result.tabs | length\'); case "$tab_count" in \'\'|*[!0-9]*) [ -n "$tab_id" ] && herdr tab close "$tab_id" >/dev/null ;; *) if [ "$tab_count" -le 1 ]; then [ -n "$workspace_id" ] && herdr workspace close "$workspace_id" >/dev/null; else [ -n "$tab_id" ] && herdr tab close "$tab_id" >/dev/null; fi ;; esac'
			),
		},
	},
}
