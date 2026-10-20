{ user, ... }:
{
  imports = [ ../../modules/home-manager/development.nix ];

  home.username = user.name;
  # Compatibility baseline for this new Home Manager configuration.
  home.stateVersion = "26.05";
}
