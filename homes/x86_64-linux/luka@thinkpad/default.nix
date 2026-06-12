{ pkgs, zen-browser, ... }:

let
  navigateMod = "ALT";
  keyboard = import ../../../systems/x86_64-linux/thinkpad/keyboard.nix;
in

{
  home.username = "luka";
  home.homeDirectory = "/home/luka";

  home.packages = with pkgs; [
    codex
    lazygit
    ghostty
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  programs.home-manager.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    systemd.enable = true;
    settings = {
      "$mainMod" = "SUPER";
      "$terminal" = "ghostty";
      "$fileManager" = "dolphin";
      "$menu" = "hyprlauncher";

      "exec-once" = [
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      input = {
        kb_model = keyboard.xkb.model;
        kb_layout = keyboard.xkb.layout;
        kb_variant = keyboard.xkb.variant;
        kb_options = keyboard.xkb.options;
      };

      bind = [
        "$mainMod, Q, exec, $terminal"
        "$mainMod, C, killactive,"
        "$mainMod, M, exec, command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"
        "$mainMod, E, exec, $fileManager"
        "$mainMod, V, togglefloating,"
        "$mainMod, R, exec, $menu"
        "$mainMod SHIFT, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy"

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

        "${navigateMod} SHIFT, 1, movetoworkspace, 1"
        "${navigateMod} SHIFT, 2, movetoworkspace, 2"
        "${navigateMod} SHIFT, 3, movetoworkspace, 3"
        "${navigateMod} SHIFT, 4, movetoworkspace, 4"
        "${navigateMod} SHIFT, 5, movetoworkspace, 5"

        "$mainMod, W, killactive"
        "$mainMod, SPACE, exec, wofi --show drun"
      ];

      bindel = [
        ", XF86MonBrightnessUp, exec, brightnessctl set 10%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 10%-"
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

  home.stateVersion = "26.05";
}
