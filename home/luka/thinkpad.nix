{ user, ... }:
{
  imports = [
    ./default.nix
    ../../modules/home-manager/hyprland/default.nix
    ../../modules/home-manager/ghostty.nix
    ../../modules/home-manager/firefox.nix
  ];
  home.homeDirectory = "/home/${user.name}";
}
