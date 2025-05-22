local colors = require("colors")
local settings = require("settings")
local app_icons = require("helpers.app_icons")
local sbar = require("sketchybar")

sbar.add("event", "aerospace_workspace_change")

local workspaces = {}

local function add_workspace(space_id, workspace_id)
	local i = workspace_id
	local space = sbar.add("space", "space." .. i, {
		space = space_id,
		icon = {
			font = { family = settings.font.numbers, size = 18 },
			string = workspace_id,
			padding_left = 15,
			padding_right = 8,
			color = colors.white,
			highlight_color = colors.green,
		},
		label = {
			padding_right = 20,
			color = colors.grey,
			highlight_color = colors.white,
			font = "sketchybar-app-font:Regular:16.0",
			y_offset = -1,
		},
		padding_right = 1,
		padding_left = 1,
		background = {
			color = colors.bg1,
			border_width = 1,
			height = 26,
			border_color = colors.black,
		},
		popup = { background = { border_width = 5, border_color = colors.black } },
	})

	workspaces[i] = space

	-- Single item bracket for space items to achieve double border on highlight
	local space_bracket = sbar.add("bracket", { space.name }, {
		background = {
			color = colors.transparent,
			border_color = colors.bg2,
			height = 28,
			border_width = 2,
		},
	})

	-- Padding space
	sbar.add("space", "space.padding." .. i, {
		space = i,
		script = "",
		width = settings.group_paddings,
	})

	space:subscribe("space_change", function(env)
		local selected = env.SELECTED == "true"
		space:set({
			icon = { highlight = selected },
			label = { highlight = selected },
			background = { border_color = selected and colors.black or colors.bg2 },
		})
		space_bracket:set({
			background = { border_color = selected and colors.grey or colors.bg2 },
		})
	end)
end

-- Function to execute shell commands and return the output
local function execute_command(command)
	local handle = io.popen(command)
	local result = handle:read("*a")
	handle:close()
	return result
end

-- Get monitor information
local monitors = {}
local monitor_output = execute_command("aerospace list-monitors")
for line in monitor_output:gmatch("[^\r\n]+") do
	local id, name = line:match("(%d+) | (.+)")
	if id and name then
		monitors[tonumber(id)] = name
	end
end

-- Get workspaces for each monitor
for monitor_id, _ in pairs(monitors) do
	local workspace_output = execute_command("aerospace list-workspaces --monitor " .. monitor_id)
	for workspace_id in workspace_output:gmatch("[^\r\n]+") do
		add_workspace(monitor_id, tonumber(workspace_id))
	end
end

local space_window_observer = sbar.add("item", {
	drawing = false,
	updates = true,
})

space_window_observer:subscribe({ "aerospace_workspace_change" }, function(env)
	sbar.exec(
		[[aerospace list-windows --workspace ]] .. tostring(env.FOCUSED_WORKSPACE) .. [[ | awk -F '|' '{print $2}']],
		function(appNames)
			local appCounts = {}
			-- Split the input string by newline into individual app names
			for appName in string.gmatch(appNames, "[^\r\n]+") do
				-- Trim leading and trailing whitespace
				appName = appName:match("^%s*(.-)%s*$")
				if appCounts[appName] then
					appCounts[appName] = appCounts[appName] + 1
				else
					appCounts[appName] = 1
				end
			end

			local icon_line = ""
			local no_app = true
			for app, count in pairs(appCounts) do
				no_app = false
				local lookup = app_icons[app]
				local icon = ((lookup == nil) and app_icons["Default"] or lookup)
				icon_line = icon_line .. icon
			end

			if no_app then
				icon_line = " —"
			end

			sbar.animate("tanh", 10, function()
				workspaces[tonumber(env.FOCUSED_WORKSPACE)]:set({ label = icon_line })
			end)
		end
	)
end)
