-- Aurora Hyprland

-- Core Configuration

require("config.variables")
require("config.env")
require("config.monitor")
require("config.general")
require("config.decoration")
require("config.animation")
require("config.input")
require("config.layout")
require("config.windowrules")
require("config.layerules")
require("config.startup")
require("config.keybinds")
require("config.misc")

-- Aurora Theme

require("config.theme")

-- Runtime Monitor Profiles
--
-- Keep this last so a profile selected by hyprmoncfg overrides the
-- inventory-generated baseline monitor rules in config.monitor.

-- Home Manager seeds the writable generated module before Hyprland starts.
-- Keep this as a direct require so hyprmoncfg can verify that its output is
-- actually consumed before replacing the file.
require("monitors")
