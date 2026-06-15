{ pkgs, ... }:

{
  home.packages = with pkgs; [
    libnotify
  ];

  services.mako = {
    enable = true;
    settings = {
      default-timeout = 6000;
      border-radius = 8;
      padding = "12,16";
    };
  };

  xdg.configFile."ghostty/config".text = ''
    desktop-notifications = true
    notify-on-command-finish = unfocused
    notify-on-command-finish-action = no-bell,notify
    notify-on-command-finish-after = 5s
  '';
}
