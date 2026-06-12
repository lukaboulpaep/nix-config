{ pkgs, zen-browser, ... }:

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
