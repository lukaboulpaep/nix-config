{
  imports = [
    ../default.nix
    ../../../modules/home/wayland
  ];

  xdg.configFile."caelestia/cli.json".text = builtins.toJSON {
    record.extraArgs = [
      "-fallback-cpu-encoding"
      "yes"
    ];
  } + "\n";
}
