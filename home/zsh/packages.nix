{ pkgs, ... }:

{
  home.packages = with pkgs; [

    # Modern CLI
    bat
    eza
    fd
    jq
    ripgrep
  ];
}
