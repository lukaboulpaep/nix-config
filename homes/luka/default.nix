{ pkgs, zen-browser, inputs, ... }:

{
  home.username = "luka";
  home.homeDirectory = "/home/luka";

  home.packages = with pkgs; [
    bruno
    codex
    gh
    lazygit
    ghostty
    mpv
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    _1password-gui
    zed-editor
    inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  programs.home-manager.enable = true;
  programs.bash.enable = true;

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  home.file = {
    ".face" = {
      source = ../../assets/profile/face.jpg;
      force = true;
    };

    "Pictures/Wallpapers/bluehour.jpg" = {
      source = ../../assets/wallpapers/bluehour.jpg;
      force = true;
    };

    "Pictures/Wallpapers/corals-fish-underwater.jpg" = {
      source = ../../assets/wallpapers/corals-fish-underwater.jpg;
      force = true;
    };
  };

  home.stateVersion = "26.05";
}
