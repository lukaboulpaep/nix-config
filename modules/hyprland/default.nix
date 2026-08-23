{ pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  services.displayManager.defaultSession = "hyprland-uwsm";

  security.pam.services.hyprlock = { };

  environment.systemPackages = with pkgs; [

    # Cursor
    hyprcursor

    # Clipboard
    wl-clipboard
    cliphist

    # Hardware / Media Controls
    brightnessctl
    playerctl
    libinput

    # Wayland Utilities
    wayland-utils
  ];
}
