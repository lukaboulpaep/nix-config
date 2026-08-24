{
  hostConfig,
  lib,
  pkgs,
  ...
}:

let
  staticConfigFiles = builtins.readDir ./config;
  staticConfigEntries = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "hypr/config/${name}" {
      source = ./config/${name};
    }
  ) staticConfigFiles;

  externalKeyboardConfig = lib.concatMapStringsSep "\n" (device: ''
    hl.device({
      name = "${device}",
      kb_layout = "us",
      kb_options = "",
    })
  '') hostConfig.keyboards.externalUS;
in
{
  assertions = [
    {
      assertion = builtins.pathExists (
        ../../assets/wallpapers + "/${hostConfig.desktop.defaultWallpaper}"
      );
      message = "The default wallpaper '${hostConfig.desktop.defaultWallpaper}' is not in assets/wallpapers.";
    }
  ];

  xdg.configFile = staticConfigEntries // {
    "systemd/user/plasma-polkit-agent.service.d/environment.conf".text = ''
      [Unit]
      PartOf=graphical-session.target
      After=graphical-session.target
      ConditionEnvironment=WAYLAND_DISPLAY

      [Service]
      Environment=QT_STYLE_OVERRIDE=
      Environment=QT_QPA_PLATFORM=wayland
    '';

    "hypr/hyprland.lua".source = ./hyprland.lua;

    "hypr/xdph.conf".text = ''
      screencopy {
        max_fps = ${toString hostConfig.desktop.screenShareMaxFps}
      }
    '';

    "hypr/config/variables.lua".text = ''
      local M = {}

      M.mainMod = "SUPER"
      M.altMod = "ALT"
      M.terminal = "${hostConfig.desktop.terminal}"
      M.browser = "${hostConfig.desktop.browser}"
      M.fileManager = "${hostConfig.desktop.fileManager}"
      M.editor = "nvim"
      M.guieditor = "zeditor"
      M.menu = "qs ipc call launcher toggle"
      M.colorscheme = "qs ipc call theme toggle"
      M.screenshot = [[grim -g "$(slurp)" - | swappy -f -]]
      M.scriptDir = os.getenv("HOME") .. "/.config/hypr/scripts"
      M.wallpaperDir = os.getenv("HOME") .. "/Wallpapers"
      M.wallpaperScript = "qs ipc call wallpaper toggle"
      M.volumeUp = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
      M.volumeDown = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      M.volumeMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      M.micMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      M.brightnessUp = "brightnessctl -e4 -n2 set 5%+"
      M.brightnessDown = "brightnessctl -e4 -n2 set 5%-"
      M.mediaPlay = "playerctl play-pause"
      M.mediaNext = "playerctl next"
      M.mediaPrev = "playerctl previous"

      return M
    '';

    "hypr/config/monitor.lua".text = ''
      hl.monitor({
        output = "${hostConfig.desktop.internalMonitor}",
        mode = "${hostConfig.desktop.monitorMode}",
        position = "auto",
        scale = "auto",
      })

      hl.monitor({
        output = "",
        mode = "preferred",
        position = "auto",
        scale = "auto",
      })
    '';

    "hypr/config/input.lua".text = ''
      hl.config({
        input = {
          kb_layout = "${hostConfig.locale.xkbLayout}",
          kb_options = "",
          follow_mouse = 1,
          sensitivity = 0,
          accel_profile = "flat",
          touchpad = {
            natural_scroll = false,
            scroll_factor = 0.80,
            tap_to_click = true,
            tap_and_drag = true,
            drag_lock = false,
            disable_while_typing = true,
            clickfinger_behavior = true,
            middle_button_emulation = false,
            tap_button_map = "lrm",
          },
        },
      })

      hl.gesture({
        fingers = 3,
        direction = "horizontal",
        action = "workspace",
      })

      ${externalKeyboardConfig}
    '';

    "hypr/scripts/restore-wallpaper.sh".source = ./scripts/restore-wallpaper.sh;

    "aurora/default-wallpaper".text = hostConfig.desktop.defaultWallpaper + "\n";
  };

  systemd.user.targets.hyprland-session.Unit = {
    Description = "Hyprland compositor session";
    Wants = [
      "graphical-session-pre.target"
      "graphical-session.target"
    ];
    After = [ "graphical-session-pre.target" ];
    Before = [ "graphical-session.target" ];
  };

  systemd.user.targets.desktop-services = {
    Unit = {
      Description = "Aurora desktop services";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Wants = [
        "quickshell.service"
        "awww-daemon.service"
        "plasma-polkit-agent.service"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.awww-daemon = {
    Unit = {
      Description = "Awww Wayland wallpaper daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "exec";
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "session.slice";
    };
    Install.WantedBy = [ "desktop-services.target" ];
  };
}
