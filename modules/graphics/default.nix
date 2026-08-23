{
  hostConfig,
  lib,
  pkgs,
  ...
}:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = lib.optionals hostConfig.features.intelGraphics (
      with pkgs;
      [
        intel-media-driver
        vpl-gpu-rt
      ]
    );
  };
}
