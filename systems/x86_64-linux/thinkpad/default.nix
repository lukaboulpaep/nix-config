{ inputs, pkgs, zen-browser, ... }:

let
  keyboard = import ./keyboard.nix;
in

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "thinkpad";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Brussels";

  console.keyMap = keyboard.consoleKeyMap;

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "nl_BE.UTF-8";
    LC_MONETARY = "nl_BE.UTF-8";
    LC_MEASUREMENT = "nl_BE.UTF-8";
  };

  services.xserver.xkb = keyboard.xkb;

  users.users.luka = {
    isNormalUser = true;
    description = "Luka Boulpaep";
    extraGroups = [ "wheel" "networkmanager" ];
  };

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

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs zen-browser;
    };
    users.luka = import (../../../homes/x86_64-linux + "/luka@thinkpad");
  };

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    # for docking
    HandleLidSwitchExternalPower = "ignore";
  };

  security.pam.services.hyprlock = { };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    brightnessctl
    cliphist
    git
    hyprlock
    hyprpaper
    vim
    waybar
    wl-clipboard
    wofi
  ];

  system.stateVersion = "26.05";
}
