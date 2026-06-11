{ config, lib, pkgs, zen-browser, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "thinkpad";

  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Brussels";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "nl_BE.UTF-8";
    LC_MONETARY = "nl_BE.UTF-8";
    LC_MEASUREMENT = "nl_BE.UTF-8";
  };

  users.users.luka = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.displayManager.defaultSession = "hyprland";

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    ghostty
    waybar
    wofi
    hyprpaper
    hyprlock
    brightnessctl
    vim
    git
    lazygit
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    wl-clipboard
    cliphist
  ];

  system.stateVersion = "26.05";
}

