{ lib, pkgs, ... }:
let
  theme = import ../../lib/theme.nix;
  ghosttyTheme = palette: {
    inherit (palette) background foreground;
    cursor-color = palette.accent;
    cursor-text = palette.background;
    selection-background = palette.selection;
    selection-foreground = palette.foreground;
    palette = lib.imap0 (index: color: "${toString index}=${color}") palette.ansi;
  };
in
{
  home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];

  programs.ghostty = {
    enable = true;
    settings = {
      font-family = theme.fonts.mono;
      window-title-font-family = theme.fonts.ui;
      # Keep terminal cells clear of the compositor's rounded corners.
      # Ghostty measures padding in points and scales it for the display.
      window-padding-x = 10;
      window-padding-y = 10;
      theme = "light:Desktop Light,dark:Desktop Dark";
      # Keep app-specified colors legible even when a running TUI retains
      # colors from the previous light/dark mode.
      minimum-contrast = 4.5;
    };
    themes = {
      "Desktop Light" = ghosttyTheme (
        theme.palettes.light
        // {
          # Share the deeper cream used by the bar and Firefox's tab header.
          background = theme.palettes.light.frame;
        }
      );
      "Desktop Dark" = ghosttyTheme theme.palettes.dark;
    };
  };
}
