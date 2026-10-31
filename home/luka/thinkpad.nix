{
  config,
  lib,
  user,
  ...
}:
{
  imports = [
    ./default.nix
    ../../modules/home-manager/hyprland/default.nix
    ../../modules/home-manager/ghostty.nix
    ../../modules/home-manager/firefox.nix
  ];
  home.homeDirectory = "/home/${user.name}";

  # Adopt the existing profile so bookmarks, sessions and extensions stay put.
  programs.firefox.profiles.default.path = "aa52fdz5.default";
  programs.firefox.profiles.default.settings."toolkit.profiles.storeID" = "6acb618c";
  home.activation.backupFirefoxProfileRegistry = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    registry=${lib.escapeShellArg "${config.home.homeDirectory}/${config.programs.firefox.configPath}/profiles.ini"}
    if [[ -f "$registry" && ! -L "$registry" ]]; then
      run mv --backup=numbered "$registry" "$registry.before-home-manager"
    fi
  '';
}
