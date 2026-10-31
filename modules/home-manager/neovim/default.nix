{ config, pkgs, neovim, ... }:
{
  home.packages = [
    neovim
    (pkgs.writeShellScriptBin "v" ''
      exec ${neovim}/bin/nvim "$@"
    '')
  ];

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "/etc/nixos/modules/home-manager/neovim";
}
