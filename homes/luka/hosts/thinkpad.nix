{
  imports = [
    ../default.nix
    ../../../modules/home/wayland
  ];

  services.luka-shell.enable = true;
}
