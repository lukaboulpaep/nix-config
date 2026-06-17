{ pkgs, ... }:

{
  home.packages = with pkgs; [
    networkmanagerapplet
    pavucontrol
    playerctl
  ];

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      targets = [ "graphical-session.target" ];
    };

    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 38;
      margin-top = 8;
      margin-left = 10;
      margin-right = 10;
      spacing = 8;

      modules-left = [
        "hyprland/workspaces"
        "hyprland/window"
      ];
      modules-center = [
        "clock"
      ];
      modules-right = [
        "pulseaudio"
        "backlight"
        "network"
        "battery"
        "tray"
      ];

      "hyprland/workspaces" = {
        format = "{name}";
        persistent-workspaces = {
          "*" = 5;
        };
      };

      "hyprland/window" = {
        format = "{}";
        max-length = 56;
        separate-outputs = true;
      };

      clock = {
        format = "{:%a %d %b  %H:%M}";
        tooltip-format = "{:%A, %d %B %Y}";
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "muted";
        format-icons = {
          default = [
            "vol"
            "vol"
            "vol"
          ];
        };
        on-click = "pavucontrol";
      };

      backlight = {
        format = "light {percent}%";
      };

      network = {
        format-wifi = "{essid}";
        format-ethernet = "wired";
        format-disconnected = "offline";
        tooltip-format-wifi = "{essid} {signalStrength}%";
        on-click = "nm-connection-editor";
      };

      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{capacity}%";
        format-charging = "{capacity}% charging";
        format-plugged = "{capacity}% plugged";
        format-warning = "{capacity}% low";
        format-critical = "{capacity}% critical";
      };

      tray = {
        icon-size = 16;
        spacing = 10;
      };
    };

    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: Inter, sans-serif;
        font-size: 13px;
        min-height: 0;
      }

      window#waybar {
        background: rgba(13, 15, 20, 0.58);
        border: 1px solid rgba(244, 241, 236, 0.20);
        border-radius: 14px;
        color: #f4f1ec;
      }

      tooltip {
        background: rgba(17, 19, 24, 0.94);
        border: 1px solid rgba(244, 241, 236, 0.18);
        border-radius: 10px;
      }

      #workspaces {
        padding: 4px;
      }

      #workspaces button {
        color: rgba(244, 241, 236, 0.68);
        padding: 0 10px;
        margin: 0 2px;
        border-radius: 10px;
      }

      #workspaces button.active {
        background: rgba(242, 184, 162, 0.24);
        color: #ffffff;
      }

      #workspaces button.urgent {
        background: rgba(248, 113, 113, 0.28);
        color: #ffffff;
      }

      #window {
        color: rgba(244, 241, 236, 0.72);
      }

      #clock,
      #pulseaudio,
      #backlight,
      #network,
      #battery,
      #tray {
        background: rgba(244, 241, 236, 0.10);
        border-radius: 10px;
        margin: 5px 0;
        padding: 0 10px;
      }

      #battery.warning {
        color: #facc15;
      }

      #battery.critical {
        color: #fb7185;
      }
    '';
  };
}
