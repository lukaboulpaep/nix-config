{ hostName, hostConfig, ... }:

{
  networking.hostName = hostName;
  time.timeZone = hostConfig.timeZone;
  i18n.defaultLocale = hostConfig.locale;
  console.keyMap = hostConfig.consoleKeyMap;

  programs.zsh.enable = true;
  security.sudo.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
