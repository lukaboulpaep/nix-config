{
  user = {
    name = "luka";
    fullName = "Luka Boulpaep";
    email = "lukaboulpaep@outlook.com";
  };

  nixosHosts = {
    thinkpad = {
      system = "x86_64-linux";
      module = ../hosts/thinkpad/configuration.nix;
      userName = "luka";
      homeModule = ../home/luka/thinkpad.nix;
      timeZone = "Europe/Brussels";
      locale = "en_US.UTF-8";
      consoleKeyMap = "uk";
      keyboardLayout = "gb";
    };
  };

  # Activate after confirming the MacBook's architecture and login name.
  darwinHosts = {
    # macbook = {
    #   system = "aarch64-darwin"; # Use x86_64-darwin for an Intel Mac.
    #   userName = "luka"; # Must match the existing macOS account.
    #   module = ../hosts/macbook/configuration.nix;
    #   homeModule = ../home/luka/macbook.nix;
    #   timeZone = "Europe/Brussels";
    # };
  };
}
