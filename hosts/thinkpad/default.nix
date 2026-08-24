{
  hostConfig,
  hostName,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/core
    ../../modules/boot
    ../../modules/networking
    ../../modules/users
    ../../modules/packages
    ../../modules/polkit
    ../../modules/programming
  ]
  ++ lib.optionals hostConfig.features.audio [
    ../../modules/audio
  ]
  ++ lib.optionals hostConfig.features.desktop [
    ../../modules/fonts
    ../../modules/graphics
    ../../modules/xdg
    ../../modules/notifications
    ../../modules/hyprland
    ../../modules/desktop
    ../../modules/session
    ../../modules/stylix
  ]
  ++ lib.optionals hostConfig.features.bluetooth [
    ../../modules/bluetooth
  ]
  ++ lib.optionals hostConfig.features.camera [
    ../../modules/camera
  ]
  ++ lib.optionals hostConfig.features.battery [
    ../../modules/power
  ]
  ++ lib.optionals hostConfig.features.containers [
    ../../modules/containers
  ];

  networking.hostName = hostName;
  services.flatpak.enable = hostConfig.features.desktop;
}
