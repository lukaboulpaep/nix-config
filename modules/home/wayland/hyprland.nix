{ hostKeyboard, hostMonitors, lib, pkgs, ... }:

let
  navigateMod = "ALT";
  keyboard = hostKeyboard;
  monitors = hostMonitors;
  lidSwitch = pkgs.writeShellScript "hyprland-lid-switch" ''
    internal_monitor="${monitors.internal.name}"
    internal_mode="${monitors.internal.mode}"
    internal_position="${monitors.internal.position}"
    internal_scale="${monitors.internal.scale}"

    case "$1" in
      close)
        if hyprctl monitors | awk -v internal="$internal_monitor" '$1 == "Monitor" && $2 != internal { found = 1 } END { exit found ? 0 : 1 }'; then
          hyprctl keyword monitor "$internal_monitor, disable"
        else
          systemctl suspend
        fi
        ;;
      open)
        hyprctl keyword monitor "$internal_monitor, $internal_mode, $internal_position, $internal_scale"
        ;;
    esac
  '';
  micMute = pkgs.writeShellScript "hyprland-mic-mute" ''
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

    if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
      swayosd-client --custom-icon microphone-sensitivity-muted --custom-message "Microphone muted"
    else
      swayosd-client --custom-icon microphone-sensitivity-high --custom-message "Microphone on"
    fi
  '';
  mkDeviceKeyboard = device: {
    name = device.hyprlandDevice;
    kb_model = device.xkb.model;
    kb_layout = device.xkb.layout;
    kb_variant = device.xkb.variant;
    kb_options = device.xkb.options;
  };
in

{
  home.packages = with pkgs; [
    swayosd
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    systemd.enable = true;
    settings = {
      "$mainMod" = "SUPER";
      "$terminal" = "ghostty";
      "$fileManager" = "dolphin";

      monitor = monitors.hyprland;

      "exec-once" = [
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      input = {
        kb_model = keyboard.defaultXkb.model;
        kb_layout = keyboard.defaultXkb.layout;
        kb_variant = keyboard.defaultXkb.variant;
        kb_options = keyboard.defaultXkb.options;
      };

      device = map mkDeviceKeyboard keyboard.hyprlandDevices;

      general = {
        border_size = 2;
        "col.active_border" = "rgba(ffffffff)";
        "col.inactive_border" = "rgba(ffffffff)";
      };

      decoration = {
        rounding = 8;
        blur.enabled = false;
        shadow.enabled = false;
      };

      bind = [
        "$mainMod, Q, exec, $terminal"
        "$mainMod, C, killactive,"
        "$mainMod, M, global, caelestia:session"
        "$mainMod, E, exec, $fileManager"
        "$mainMod, V, togglefloating,"
        "$mainMod, R, global, caelestia:launcher"
        "$mainMod, SPACE, global, caelestia:launcher"
        "$mainMod, N, global, caelestia:nexus"
        "$mainMod, D, global, caelestia:dashboard"
        "$mainMod, S, global, caelestia:sidebar"
        "$mainMod, U, global, caelestia:utilities"
        "$mainMod SHIFT, V, exec, caelestia clipboard"

        "${navigateMod}, H, movefocus, l"
        "${navigateMod}, J, movefocus, d"
        "${navigateMod}, K, movefocus, u"
        "${navigateMod}, L, movefocus, r"

        "${navigateMod} SHIFT, H, movewindow, l"
        "${navigateMod} SHIFT, J, movewindow, d"
        "${navigateMod} SHIFT, K, movewindow, u"
        "${navigateMod} SHIFT, L, movewindow, r"

        "${navigateMod}, 1, workspace, r~1"
        "${navigateMod}, 2, workspace, r~2"
        "${navigateMod}, 3, workspace, r~3"
        "${navigateMod}, 4, workspace, r~4"
        "${navigateMod}, 5, workspace, r~5"

        "${navigateMod} SHIFT, 1, movetoworkspace, r~1"
        "${navigateMod} SHIFT, 2, movetoworkspace, r~2"
        "${navigateMod} SHIFT, 3, movetoworkspace, r~3"
        "${navigateMod} SHIFT, 4, movetoworkspace, r~4"
        "${navigateMod} SHIFT, 5, movetoworkspace, r~5"

        "${navigateMod}, Tab, focusmonitor, +1"
        "${navigateMod} SHIFT, Tab, movecurrentworkspacetomonitor, +1"

        "$mainMod, W, killactive"
        "$mainMod SHIFT, SPACE, exec, hyprctl switchxkblayout all next"
      ];

      bindl = lib.optionals (monitors.hasLid or false) [
        ", switch:on:Lid Switch, exec, ${lidSwitch} close"
        ", switch:off:Lid Switch, exec, ${lidSwitch} open"
      ];

      bindel = [
        ", XF86MonBrightnessUp, exec, brightnessctl set 10%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
        ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume +10 --max-volume 100"
        ", XF86AudioLowerVolume, exec, swayosd-client --output-volume -10"
        ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
        ", XF86AudioMicMute, exec, ${micMute}"
      ];
    };
  };

  services.hypridle = {
    enable = true;
    systemdTarget = "graphical-session.target";
    settings = {
      general = {
        after_sleep_cmd = "hyprctl dispatch dpms on";
        before_sleep_cmd = "loginctl lock-session";
        lock_cmd = "pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
      };
    };
  };
}
