{ config, lib, pkgs, zen-browser, inputs, ... }:

{
  imports = [
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  home.username = "luka";
  home.homeDirectory = "/home/luka";

  home.packages = with pkgs;
    [
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
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [ flatpak ];

  programs.home-manager.enable = true;
  programs.bash.enable = true;

  services.flatpak = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    packages = [
      {
        appId = "sh.cider.Cider";
        origin = "flathub";
      }
    ];
  };

  xdg.systemDirs.data = lib.mkIf pkgs.stdenv.isLinux [
    "${config.home.homeDirectory}/.local/share/flatpak/exports/share"
    "/var/lib/flatpak/exports/share"
  ];

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
