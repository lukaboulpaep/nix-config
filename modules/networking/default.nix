{ ... }:

{
  networking.networkmanager.enable = true;

  # A desktop session does not need to block boot until a network is online.
  systemd.services.NetworkManager-wait-online.enable = false;
}
