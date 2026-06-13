{ pkgs, zen-browser, ... }:

{
  home.username = "luka";
  home.homeDirectory = "/home/luka";

  home.packages = with pkgs; [
    codex
    lazygit
    ghostty
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    _1password-gui
  ];

  programs.home-manager.enable = true;

  home.stateVersion = "26.05";
}
