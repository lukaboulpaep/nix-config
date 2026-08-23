{
  hostConfig,
  lib,
  ...
}:

{
  services.power-profiles-daemon.enable = true;
  services.upower = {
    enable = true;
    percentageLow = 20;
    percentageCritical = 10;
    percentageAction = 5;

    criticalPowerAction = "PowerOff";
  };
  powerManagement.enable = true;
  networking.networkmanager.wifi.powersave = false;
  zramSwap.enable = true;

  services.logind.settings.Login = lib.mkIf hostConfig.features.lid {
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };
}
