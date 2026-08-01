{ inputs, lib, pkgs, zen-browser, ... }:

let
  keyboard = import ./keyboard.nix;
  monitors = import ./monitors.nix;
in

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/audio
    ../../modules/nixos/wayland/hyprland.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "thinkpad";
  networking.networkmanager.enable = true;

  services.flatpak.enable = true;

  time.timeZone = "Europe/Brussels";

  console.keyMap = keyboard.consoleKeyMap;

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_TIME = "nl_BE.UTF-8";
    LC_MONETARY = "nl_BE.UTF-8";
    LC_MEASUREMENT = "nl_BE.UTF-8";
  };

  services.xserver.xkb = keyboard.defaultXkb;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
    ];
  };

  users.users.luka = {
    isNormalUser = true;
    description = "Luka Boulpaep";
    extraGroups = [ "wheel" "networkmanager" ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs zen-browser;
      hostKeyboard = keyboard;
      hostMonitors = monitors;
    };
    users.luka = import ../../homes/luka/hosts/thinkpad.nix;
  };

  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    # for docking
    HandleLidSwitchExternalPower = "ignore";
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "1password"
    ];

  environment.systemPackages = with pkgs; [
    brightnessctl
    git
    vim
  ];

  system.stateVersion = "26.05";
}
