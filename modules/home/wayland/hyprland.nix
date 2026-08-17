{ config, hostKeyboard, hostMonitors, lib, pkgs, ... }:

let
  navigateMod = "ALT";
  keyboard = hostKeyboard;
  monitors = hostMonitors;
  wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/bluehour.jpg";
  launcher = "fuzzel";
  clipboardMenu = pkgs.writeShellScript "hyprland-clipboard-menu" ''
    selection="$(cliphist list | fuzzel --dmenu --prompt 'Clipboard  ')"
    [ -n "$selection" ] || exit 0

    printf '%s' "$selection" | cliphist decode | wl-copy
  '';
  powerMenu = pkgs.writeShellScript "hyprland-power-menu" ''
    choice="$(printf '%s\n' Lock Suspend Reboot Shutdown Logout | fuzzel --dmenu --prompt 'Power  ')"

    case "$choice" in
      Lock) loginctl lock-session ;;
      Suspend) systemctl suspend ;;
      Reboot) systemctl reboot ;;
      Shutdown) systemctl poweroff ;;
      Logout) hyprctl dispatch exit ;;
    esac
  '';
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
  monitorWorkspaces = pkgs.writeShellScript "hyprland-monitor-workspaces" ''
    internal_monitor="${monitors.internal.name}"
    jq="${pkgs.jq}/bin/jq"
    socat="${pkgs.socat}/bin/socat"

    apply_workspace_layout() {
      external_monitor="$(
        hyprctl monitors -j \
          | "$jq" -r --arg internal "$internal_monitor" '[.[] | select(.name != $internal)] | sort_by(.x) | .[0].name // empty'
      )"

      if [ -n "$external_monitor" ]; then
        primary_monitor="$external_monitor"
        secondary_monitor="$internal_monitor"
      else
        primary_monitor="$internal_monitor"
        secondary_monitor="$internal_monitor"
      fi

      for workspace in 1 2 3 4 5; do
        hyprctl keyword workspace "$workspace, monitor:$primary_monitor, persistent:true"
        hyprctl dispatch moveworkspacetomonitor "$workspace $primary_monitor" >/dev/null 2>&1 || true
      done

      for workspace in 6 7 8 9 10; do
        hyprctl keyword workspace "$workspace, monitor:$secondary_monitor, persistent:true"
        hyprctl dispatch moveworkspacetomonitor "$workspace $secondary_monitor" >/dev/null 2>&1 || true
      done

      if [ -n "$external_monitor" ]; then
        hyprctl dispatch focusmonitor "$external_monitor"
        hyprctl dispatch workspace 1
      fi
    }

    apply_workspace_layout

    socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
    [ -S "$socket" ] || exit 0

    "$socat" -U - UNIX-CONNECT:"$socket" | while read -r event; do
      case "$event" in
        monitoradded*|monitorremoved*)
          sleep 1
          apply_workspace_layout
          ;;
      esac
    done
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
    brightnessctl
    fuzzel
    grimblast
    hyprpaper
    swayosd
    wl-clipboard
  ];

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "ghostty";
        layer = "overlay";
        width = 42;
        lines = 12;
        horizontal-pad = 18;
        vertical-pad = 14;
        inner-pad = 10;
        font = "Inter:size=11";
        icons-enabled = true;
      };

      colors = {
        background = "111318dd";
        text = "f4f1ecff";
        match = "f2b8a2ff";
        selection = "2a2f36ee";
        selection-text = "ffffffff";
        selection-match = "f2b8a2ff";
        border = "f2b8a2ff";
      };

      border = {
        width = 2;
        radius = 14;
      };
    };
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      wallpaper = [
        {
          monitor = monitors.internal.name;
          path = wallpaper;
          fit_mode = "cover";
        }
      ];
      splash = false;
    };
  };

  services.swayosd.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    systemd.enable = true;
    settings = {
      "$mainMod" = "SUPER";
      "$terminal" = "ghostty";
      "$fileManager" = "thunar";

      monitor = monitors.hyprland;

      "exec-once" = [
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "${monitorWorkspaces}"
      ];

      input = {
        kb_model = keyboard.defaultXkb.model;
        kb_layout = keyboard.defaultXkb.layout;
        kb_variant = keyboard.defaultXkb.variant;
        kb_options = keyboard.defaultXkb.options;
      };

      device = map mkDeviceKeyboard keyboard.hyprlandDevices;

      general = {
        gaps_in = 6;
        gaps_out = 12;
        border_size = 2;
        resize_on_border = true;
        "col.active_border" = "rgba(f2b8a2ff) rgba(93c5fdff) 45deg";
        "col.inactive_border" = "rgba(f4f1ec33)";
      };

      decoration = {
        rounding = 12;
        rounding_power = 2;
        blur = {
          enabled = true;
          size = 8;
          passes = 3;
          vibrancy = 0.18;
        };
        shadow = {
          enabled = true;
          range = 18;
          render_power = 3;
          color = "rgba(090b10aa)";
        };
      };

      animations = {
        enabled = true;
        bezier = [
          "easeOut, 0.16, 1, 0.3, 1"
          "easeInOut, 0.65, 0, 0.35, 1"
        ];
        animation = [
          "windows, 1, 4, easeOut, popin 85%"
          "windowsOut, 1, 3, easeInOut, popin 85%"
          "border, 1, 6, easeOut"
          "fade, 1, 4, easeOut"
          "workspaces, 1, 4, easeOut, slide"
        ];
      };

      dwindle = {
        preserve_split = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        focus_on_activate = true;
      };

      bind = [
        "$mainMod, Q, exec, $terminal"
        "$mainMod, C, killactive,"
        "$mainMod, M, exec, ${powerMenu}"
        "$mainMod, E, exec, $fileManager"
        "$mainMod, V, togglefloating,"
        "$mainMod, R, exec, ${launcher}"
        "$mainMod, SPACE, exec, ${launcher}"
        "$mainMod SHIFT, V, exec, ${clipboardMenu}"
        "$mainMod, F, fullscreen,"
        "$mainMod SHIFT, Q, exit,"

        ", Print, exec, grimblast copy screen"
        "SHIFT, Print, exec, grimblast copy area"

        "${navigateMod}, H, movefocus, l"
        "${navigateMod}, J, movefocus, d"
        "${navigateMod}, K, movefocus, u"
        "${navigateMod}, L, movefocus, r"

        "${navigateMod} SHIFT, H, movewindow, l"
        "${navigateMod} SHIFT, J, movewindow, d"
        "${navigateMod} SHIFT, K, movewindow, u"
        "${navigateMod} SHIFT, L, movewindow, r"

        "${navigateMod}, 1, workspace, 1"
        "${navigateMod}, 2, workspace, 2"
        "${navigateMod}, 3, workspace, 3"
        "${navigateMod}, 4, workspace, 4"
        "${navigateMod}, 5, workspace, 5"
        "${navigateMod}, 6, workspace, 6"
        "${navigateMod}, 7, workspace, 7"
        "${navigateMod}, 8, workspace, 8"
        "${navigateMod}, 9, workspace, 9"
        "${navigateMod}, 0, workspace, 10"

        "${navigateMod} SHIFT, 1, movetoworkspace, 1"
        "${navigateMod} SHIFT, 2, movetoworkspace, 2"
        "${navigateMod} SHIFT, 3, movetoworkspace, 3"
        "${navigateMod} SHIFT, 4, movetoworkspace, 4"
        "${navigateMod} SHIFT, 5, movetoworkspace, 5"
        "${navigateMod} SHIFT, 6, movetoworkspace, 6"
        "${navigateMod} SHIFT, 7, movetoworkspace, 7"
        "${navigateMod} SHIFT, 8, movetoworkspace, 8"
        "${navigateMod} SHIFT, 9, movetoworkspace, 9"
        "${navigateMod} SHIFT, 0, movetoworkspace, 10"

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

    extraConfig = ''
      layerrule {
        name = waybar-effects
        match:namespace = waybar
        blur = true
        ignore_alpha = 0.0
      }

      windowrule {
        name = pavucontrol-float
        match:class = ^(pavucontrol)$
        float = true
      }

      windowrule {
        name = pip-float
        match:title = ^(Picture-in-Picture)$
        float = true
      }

      windowrule {
        name = pip-pin
        match:title = ^(Picture-in-Picture)$
        pin = true
      }

      windowrule {
        name = thunar-size
        match:class = ^(thunar)$
        size = 960 640
      }

      windowrule {
        name = center-floating
        match:float = true
        center = true
      }
    '';
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
