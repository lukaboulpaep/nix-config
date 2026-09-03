{
  hostConfig,
  inventory,
  lib,
  pkgs,
  ...
}:

let
  mkUser = username: {
    isNormalUser = true;
    description = inventory.users.${username}.fullName;
    shell = if inventory.users.${username}.shell == "zsh" then pkgs.zsh else pkgs.bashInteractive;
    extraGroups = [
      "wheel"
      "networkmanager"
    ]
    ++ lib.optionals hostConfig.features.camera [ "video" ]
    ++ lib.optionals hostConfig.features.agentSandbox [ "kvm" ];
  };
in
{
  users.users = lib.genAttrs hostConfig.users mkUser;

  programs.zsh.enable = lib.any (username: inventory.users.${username}.shell == "zsh") hostConfig.users;
  security.sudo.enable = true;
}
