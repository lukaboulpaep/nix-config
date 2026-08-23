{
  config,
  hostConfig,
  lib,
  pkgs,
  userConfig,
  ...
}:

{
  imports = [
    ./git
    ./zsh
    ./ssh
    ./xdg
    ./neovim
  ]
  ++ lib.optionals hostConfig.features.desktop [
    ./hyprland
    ./quickshell
    ./theme
  ];

  home.username = userConfig.username;
  home.homeDirectory = "/home/${userConfig.username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;
  manual.manpages.enable = false;

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  home.file = {
    ".face" = {
      source = ../assets/profile/face.jpg;
      force = true;
    };
    "Wallpapers/bluehour.jpg".source = ../assets/wallpapers/bluehour.jpg;
    "Wallpapers/corals-fish-underwater.jpg".source = ../assets/wallpapers/corals-fish-underwater.jpg;
  };

  xdg.systemDirs.data = lib.optionals pkgs.stdenv.isLinux [
    "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
    "/var/lib/flatpak/exports/share"
  ];
}
