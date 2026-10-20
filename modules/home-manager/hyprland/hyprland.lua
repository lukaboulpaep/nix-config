hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.config({ input = { kb_layout = "gb" }, general = { layout = "dwindle" } })

hl.on("hyprland.start", function()
    hl.exec_cmd("ghostty")
end)

hl.bind("SUPER + Return", hl.dsp.exec_cmd("ghostty"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
