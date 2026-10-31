{ pkgs, ... }:
{
  programs.hyprland.enable = true;
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  hardware.i2c.enable = true;
  services.udev.packages = [ pkgs.brightnessctl ];
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "desktop-displays";
      runtimeInputs = [
        pkgs.python3
        pkgs.hyprland
      ];
      text = ''
        exec python3 /etc/nixos/modules/home-manager/hyprland/quickshell/displays/displays.py "$@"
      '';
    })
    (pkgs.writeShellApplication {
      name = "desktop-bluetooth";
      runtimeInputs = [ (pkgs.python3.withPackages (p: [ p.pygobject3 ])) ];
      text = ''
        exec python3 /etc/nixos/modules/home-manager/hyprland/quickshell/connections/bluetooth-agent.py "$@"
      '';
    })
    (pkgs.writeShellApplication {
      name = "desktop-brightness";
      runtimeInputs = [
        pkgs.python3
        pkgs.brightnessctl
        pkgs.ddcutil
      ];
      text = ''
        exec python3 /etc/nixos/modules/home-manager/hyprland/quickshell/brightness/brightness.py "$@"
      '';
    })
  ];
  # The Home Manager Hyprlock package needs a PAM service to authenticate.
  security.pam.services.hyprlock = { };
}
