{ hostConfig, ... }:

{
  hardware.ipu6 = {
    enable = hostConfig.hardware.camera.backend == "ipu6";
    platform = hostConfig.hardware.camera.platform;
  };
}
