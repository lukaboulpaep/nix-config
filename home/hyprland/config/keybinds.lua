-- Keybindings

-- Import Variables

local vars = require("config.variables")
local mainMod = vars.mainMod
local altMod = vars.altMod

-- Applications

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(vars.terminal))
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(vars.fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(vars.browser))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(vars.menu))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(vars.guieditor))

-- Change Colorscheme
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(vars.colorscheme))

-- Window Management

hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0"))

-- Screenshot

hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(vars.screenshot))

-- Scripts

hl.bind(mainMod .. " + P", hl.dsp.exec_cmd(vars.wallpaperScript))

-- Focus Movement
hl.bind(altMod .. " + H", hl.dsp.focus({ direction = "l" }))
hl.bind(altMod .. " + J", hl.dsp.focus({ direction = "d" }))
hl.bind(altMod .. " + K", hl.dsp.focus({ direction = "u" }))
hl.bind(altMod .. " + L", hl.dsp.focus({ direction = "r" }))

-- Monitor Focus
hl.bind(mainMod .. " + ALT + H", hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + ALT + J", hl.dsp.focus({ monitor = "d" }))
hl.bind(mainMod .. " + ALT + K", hl.dsp.focus({ monitor = "u" }))
hl.bind(mainMod .. " + ALT + L", hl.dsp.focus({ monitor = "r" }))
hl.bind(mainMod .. " + ALT + HOME", hl.dsp.focus({ monitor = vars.internalMonitor }))

-- Workspaces

-- Move the entire current workspace between monitors. Directional selectors
-- follow the physical monitor layout; HOME always returns it to the laptop.
hl.bind(mainMod .. " + CTRL + H", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(mainMod .. " + CTRL + J", hl.dsp.workspace.move({ monitor = "d" }))
hl.bind(mainMod .. " + CTRL + K", hl.dsp.workspace.move({ monitor = "u" }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.workspace.move({ monitor = "r" }))
hl.bind(mainMod .. " + CTRL + HOME", hl.dsp.workspace.move({ monitor = vars.internalMonitor }))

-- Move all numbered workspaces without replacing the single-workspace binds.
hl.bind(mainMod .. " + CTRL + SHIFT + H", hl.dsp.exec_cmd("qs ipc call display moveAll l"))
hl.bind(mainMod .. " + CTRL + SHIFT + J", hl.dsp.exec_cmd("qs ipc call display moveAll d"))
hl.bind(mainMod .. " + CTRL + SHIFT + K", hl.dsp.exec_cmd("qs ipc call display moveAll u"))
hl.bind(mainMod .. " + CTRL + SHIFT + L", hl.dsp.exec_cmd("qs ipc call display moveAll r"))
hl.bind(mainMod .. " + CTRL + SHIFT + HOME", hl.dsp.exec_cmd("qs ipc call display moveAllHome"))
hl.bind(mainMod .. " + TAB", hl.dsp.focus({ workspace = "previous" }))

for i = 1, 10 do
	local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Mouse

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Audio

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(vars.volumeUp), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(vars.volumeDown), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(vars.volumeMute), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(vars.micMute), { locked = true, repeating = true })

-- Brightness

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(vars.brightnessUp), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(vars.brightnessDown), { locked = true, repeating = true })

-- Media

hl.bind("XF86AudioNext", hl.dsp.exec_cmd(vars.mediaNext), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(vars.mediaPrev), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(vars.mediaPlay), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(vars.mediaPlay), { locked = true })
