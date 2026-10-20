{ pkgs, ... }:
{
  home.packages = [
    pkgs.neovim
    (pkgs.writeShellScriptBin "v" ''
      exec ${pkgs.neovim}/bin/nvim "$@"
    '')
  ];
}
