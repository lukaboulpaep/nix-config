{ pkgs, user, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/base.nix
    ../../modules/nixos/hyprland.nix
  ];

  users.users.${user.name} = {
    isNormalUser = true;
    description = user.fullName;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = [ pkgs.git pkgs.curl pkgs.nano ];

  programs.ssh.startAgent = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.systemd.enable = true;

  networking.networkmanager.enable = true;

  system.stateVersion = "26.05";
}
