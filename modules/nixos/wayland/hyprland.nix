{ lib, pkgs, ... }:

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

  services.logind.settings.Login = {
    HandleLidSwitch = lib.mkForce "ignore";
    HandleLidSwitchDocked = lib.mkForce "ignore";
    HandleLidSwitchExternalPower = lib.mkForce "ignore";
  };

  security.pam.services.hyprlock = { };

  environment.systemPackages = with pkgs; [
    cliphist
    hyprlock
    hyprpaper
    waybar
    wl-clipboard
    wofi
  ];
}
