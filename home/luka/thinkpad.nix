{ user, ... }:
{
  imports = [ ./default.nix ];
  home.homeDirectory = "/home/${user.name}";
}
