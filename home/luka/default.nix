{ user, ... }:
{
  imports = [
    ../../modules/home-manager/development.nix
    ../../modules/home-manager/neovim/default.nix
  ];

  home.username = user.name;
  # Compatibility baseline for this new Home Manager configuration.
  home.stateVersion = "26.05";

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."github.com" = {
      IdentityFile = "~/.ssh/id_ed25519";
      IdentitiesOnly = true;
      AddKeysToAgent = "yes";
    };
  };
}
