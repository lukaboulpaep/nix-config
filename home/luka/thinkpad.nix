{ user, ... }:
{
  imports = [
    ./default.nix
    ../../modules/home-manager/hyprland/default.nix
    ../../modules/home-manager/ghostty.nix
  ];
  home.homeDirectory = "/home/${user.name}";
}
