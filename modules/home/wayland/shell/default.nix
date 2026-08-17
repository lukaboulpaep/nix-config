{ config, lib, pkgs, ... }:

let
  cfg = config.services.luka-shell;
  shellSource = lib.cleanSourceWith {
    src = ./src;
    filter = path: _type: builtins.baseNameOf path != ".qmlls.ini";
  };
in

{
  options.services.luka-shell.enable =
    lib.mkEnableOption "the Luka Wayland desktop shell";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      networkmanagerapplet
      pavucontrol
      playerctl
      quickshell
    ];

    xdg.configFile."quickshell/luka-shell" = {
      source = shellSource;
      recursive = true;
    };

    systemd.user.services.luka-shell = {
      Unit = {
        Description = "Luka Wayland desktop shell";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
        X-Restart-Triggers = [ "${shellSource}" ];
      };

      Service = {
        ExecStart = "${lib.getExe pkgs.quickshell} --config luka-shell";
        Restart = "on-failure";
        RestartSec = 1;
      };

      Install.WantedBy = [ config.wayland.systemd.target ];
    };
  };
}
