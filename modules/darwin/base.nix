{ hostName, hostConfig, ... }:
{
  networking.hostName = hostName;
  time.timeZone = hostConfig.timeZone;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.zsh.enable = true;
}
