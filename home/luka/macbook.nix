{ user, ... }:
{
  imports = [ ./default.nix ];
  home.homeDirectory = "/Users/${user.name}";
}
