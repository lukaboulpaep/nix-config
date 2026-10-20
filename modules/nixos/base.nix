{ pkgs, codex, hostName, hostConfig, user, ... }:

{
  networking.hostName = hostName;
  time.timeZone = hostConfig.timeZone;
  i18n.defaultLocale = hostConfig.locale;
  console.keyMap = hostConfig.consoleKeyMap;

  users.users.${user.name} = {
    isNormalUser = true;
    description = user.fullName;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };
  programs.zsh.enable = true;
  security.sudo.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = [
    pkgs.git
    pkgs.curl
    pkgs.nano
    codex
  ];
}
