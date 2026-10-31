{ lib, ... }:
let
  theme = import ../../lib/theme.nix;
  paletteCss =
    palette:
    lib.concatMapStringsSep "\n" (name: "--desktop-${name}: ${palette.${name}};") [
      "frame"
      "background"
      "foreground"
      "accent"
      "outline"
      "selection"
    ];
  colors = ''
    :root {
      ${paletteCss theme.palettes.light}
      color-scheme: light !important;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        ${paletteCss theme.palettes.dark}
        color-scheme: dark !important;
      }
    }
  '';
in
{
  programs.firefox = {
    enable = true;
    profiles.default = {
      isDefault = true;
      settings = {
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "extensions.activeThemeID" = "default-theme@mozilla.org";
        "browser.theme.toolbar-theme" = 2;
        "browser.theme.content-theme" = 2;
        "layout.css.prefers-color-scheme.content-override" = 2;
        # Keep Firefox Sync from restoring a separate browser theme.
        "services.sync.prefs.sync.extensions.activeThemeID" = false;
      };
      userChrome = ''
        @media not (forced-colors: active) {
          ${colors}
          :root {
            /* Themes can paint a gradient on the window body behind the tabs. */
            --toolbox-background-image: none !important;
            --toolbox-background-color: var(--desktop-frame) !important;
            --toolbox-background-color-inactive: var(--desktop-frame) !important;
            --toolbox-text-color: var(--desktop-foreground) !important;
            --toolbox-text-color-inactive: var(--desktop-foreground) !important;
            --toolbar-background-color: var(--desktop-frame) !important;
            --toolbar-text-color: var(--desktop-foreground) !important;
            --toolbarbutton-icon-fill: var(--desktop-foreground) !important;
            --toolbarbutton-background-color-hover: var(--desktop-selection) !important;
            --toolbarbutton-background-color-active: var(--desktop-selection) !important;
            --tab-background-color-selected: var(--desktop-background) !important;
            --tab-background-color-hover: var(--desktop-selection) !important;
            --tab-text-color-selected: var(--desktop-foreground) !important;
            --tab-border-color-selected: var(--desktop-accent) !important;
            --tab-loading-fill: var(--desktop-accent) !important;
            --tab-border-color-selected-leading: var(--desktop-accent) !important;
            --tab-border-color-selected-trailing: var(--desktop-accent) !important;
            --toolbar-field-background-color: var(--desktop-background) !important;
            --toolbar-field-text-color: var(--desktop-foreground) !important;
            --toolbar-field-border-color: var(--desktop-outline) !important;
            --toolbar-field-background-color-focus: var(--desktop-background) !important;
            --toolbar-field-text-color-focus: var(--desktop-foreground) !important;
            --toolbar-field-border-color-focus: var(--desktop-accent) !important;
            --input-text-background-color: var(--desktop-background) !important;
            --input-text-color: var(--desktop-foreground) !important;
            --input-text-border-color: var(--desktop-outline) !important;
            --urlbarview-background-color-hover: var(--desktop-selection) !important;
            --urlbarview-background-color-selected: var(--desktop-selection) !important;
            --urlbarview-text-color-selected: var(--desktop-foreground) !important;
            --urlbarview-text-color-action: var(--desktop-accent) !important;
            --lwt-toolbar-field-highlight: var(--desktop-selection) !important;
            --lwt-toolbar-field-highlight-text: var(--desktop-foreground) !important;
            --chrome-content-separator-color: var(--desktop-outline) !important;
            --sidebar-background-color: var(--desktop-frame) !important;
            --sidebar-text-color: var(--desktop-foreground) !important;
            --lwt-sidebar-background-color: var(--desktop-frame) !important;
            --lwt-sidebar-text-color: var(--desktop-foreground) !important;
            --color-accent-primary: var(--desktop-accent) !important;
            --color-accent-primary-hover: var(--desktop-accent) !important;
            --color-accent-primary-active: var(--desktop-accent) !important;
            --color-accent-primary-contrast: var(--desktop-background) !important;
            --focus-outline-color: var(--desktop-accent) !important;
            --link-color: var(--desktop-accent) !important;
            font-family: "${theme.fonts.ui}", sans-serif !important;
          }
          panel, menupopup {
            --panel-background: var(--desktop-background) !important;
            --panel-color: var(--desktop-foreground) !important;
            --panel-border-color: var(--desktop-outline) !important;
            --panel-item-hover-bgcolor: var(--desktop-selection) !important;
            --panel-item-active-bgcolor: var(--desktop-selection) !important;
          }
        }
      '';
      userContent = ''
        @-moz-document url("about:home"), url("about:newtab"), url("about:blank") {
          @media not (forced-colors: active) {
            ${colors}
            :root {
              --newtab-background-color: var(--desktop-background) !important;
              --newtab-background-color-secondary: var(--desktop-frame) !important;
              --newtab-background-card: var(--desktop-frame) !important;
              --newtab-text-primary-color: var(--desktop-foreground) !important;
              --newtab-text-secondary-color: var(--desktop-foreground) !important;
              --newtab-primary-action-background: var(--desktop-accent) !important;
              --newtab-primary-element-text-color: var(--desktop-background) !important;
              --newtab-element-hover-color: var(--desktop-selection) !important;
              --newtab-element-active-color: var(--desktop-selection) !important;
              --newtab-border-color: var(--desktop-outline) !important;
              background-color: var(--desktop-background) !important;
              color: var(--desktop-foreground) !important;
            }
            body {
              background-color: var(--desktop-background) !important;
              color: var(--desktop-foreground) !important;
              font-family: "${theme.fonts.ui}", sans-serif !important;
            }
          }
        }
      '';
    };
  };
}
