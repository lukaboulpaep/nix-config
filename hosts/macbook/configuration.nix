{ user, ... }:
{
  imports = [
    ../../modules/darwin/base.nix
    ../../modules/darwin/homebrew.nix
  ];

  users.users.${user.name} = {
    name = user.name;
    home = "/Users/${user.name}";
  };

  # Initial nix-darwin compatibility baseline; independent of NixOS's value.
  system.stateVersion = 6;
}
