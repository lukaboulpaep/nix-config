{
  hostConfig,
  inputs,
  pkgs,
  ...
}:

{
  environment.systemPackages = [
    pkgs.codex
    inputs.herdr.packages.${hostConfig.system}.herdr
  ];
}
