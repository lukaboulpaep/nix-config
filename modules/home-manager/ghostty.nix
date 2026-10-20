{ pkgs, ... }:
{
  home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  programs.ghostty = {
    enable = true;
    settings.font-family = "JetBrainsMono Nerd Font";
  };
}
