-- Environment Variables

local vars = require("config.variables")

-- Cursor

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Wayland

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Qt Applications

hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- GTK Applications

hl.env("GDK_BACKEND", "wayland,x11")

-- Java Applications

hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- Electron Applications

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Misc

-- Default Applications

hl.env("EDITOR", vars.editor)
hl.env("BROWSER", vars.browser)
hl.env("TERMINAL", vars.terminal)
