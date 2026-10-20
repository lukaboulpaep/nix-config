{
  # Shared identity data can also be consumed by a future nix-darwin host.
  user = {
    name = "luka";
    fullName = "Luka Boulpaep";
  };

  nixosHosts = {
    thinkpad = {
      system = "x86_64-linux";
      module = ../hosts/thinkpad/configuration.nix;
      timeZone = "Europe/Brussels";
      locale = "en_US.UTF-8";
      consoleKeyMap = "uk";
    };
  };
}
