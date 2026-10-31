{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = import ../../lib/theme.nix;
  switchTheme = pkgs.writeShellApplication {
    name = "desktop-theme";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.glib
      pkgs.hyprland
      pkgs.procps
    ];
    text = ''
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/desktop-theme"
      mode=${lib.escapeShellArg theme.defaultMode}
      if [[ -f "$state_dir/mode" ]]; then
        read -r mode < "$state_dir/mode"
      fi
      case "$mode" in light|dark) ;; *) mode=${lib.escapeShellArg theme.defaultMode} ;; esac

      case "''${1:-get}" in
        get) printf '%s\n' "$mode"; exit 0 ;;
        light|dark) mode="$1" ;;
        toggle) if [[ "$mode" == light ]]; then mode=dark; else mode=light; fi ;;
        apply) ;;
        *) echo "Usage: desktop-theme [light|dark|toggle|get|apply]" >&2; exit 2 ;;
      esac

      # GTK and the desktop portal expose this preference to apps like Ghostty.
      export GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas
      gsettings set org.gnome.desktop.interface color-scheme "prefer-$mode"

      mkdir -p "$state_dir"
      temporary_file=$(mktemp "$state_dir/.mode.XXXXXX")
      trap 'rm -f "$temporary_file"' EXIT
      printf '%s\n' "$mode" > "$temporary_file"
      mv "$temporary_file" "$state_dir/mode"

      # Reload reads the same saved mode, including after later config edits.
      if [[ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        hyprctl reload >/dev/null
      fi

      # Ghostty does not watch its config files. Reload existing instances,
      # including Nix's wrapped binary (Linux comm names truncate at 15 chars).
      # Only signal processes that have registered a SIGUSR2 handler.
      reload_status=0
      pkill --signal USR2 --require-handler --uid "$(id -u)" \
        --exact 'ghostty|\.ghostty-wrappe' || reload_status=$?
      if (( reload_status > 1 )); then
        echo "Could not reload Ghostty (pkill exit $reload_status)" >&2
        exit "$reload_status"
      fi
      printf '%s\n' "$mode"
    '';
  };
in
{
  home.packages = [
    pkgs.plus-jakarta-sans
    switchTheme
  ];
  fonts.fontconfig = {
    enable = true;
    defaultFonts.sansSerif = [ theme.fonts.ui ];
  };

  xdg.configFile."desktop-theme/tokens.json".text = builtins.toJSON (
    theme // { applyCommand = lib.getExe switchTheme; }
  );
}
