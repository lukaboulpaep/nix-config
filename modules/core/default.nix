{
  hostConfig,
  lib,
  ...
}:

{
  time.timeZone = hostConfig.locale.timeZone;
  i18n.defaultLocale = hostConfig.locale.defaultLocale;
  i18n.extraLocaleSettings = {
    LC_TIME = hostConfig.locale.regionalLocale;
    LC_MONETARY = hostConfig.locale.regionalLocale;
    LC_MEASUREMENT = hostConfig.locale.regionalLocale;
  };

  console.keyMap = hostConfig.locale.consoleKeyMap;
  services.xserver.xkb = {
    model = "pc105";
    layout = hostConfig.locale.xkbLayout;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  documentation.enable = false;

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "1password"
  ];

  system.stateVersion = "26.05";
}
