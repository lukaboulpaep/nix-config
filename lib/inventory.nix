{
  users = {
    luka = {
      username = "luka";
      fullName = "Luka Boulpaep";
      email = "lukaboulpaep@outlook.com";
      shell = "zsh";
      profiles = [ "personal" ];
    };
  };

  hosts = {
    thinkpad = {
      module = ../hosts/thinkpad;
      system = "x86_64-linux";
      users = [ "luka" ];

      locale = {
        timeZone = "Europe/Brussels";
        defaultLocale = "en_US.UTF-8";
        regionalLocale = "nl_BE.UTF-8";
        consoleKeyMap = "uk";
        xkbLayout = "gb";
      };

      features = {
        desktop = true;
        audio = true;
        bluetooth = true;
        battery = true;
        lid = true;
        intelGraphics = true;
        camera = true;
        containers = true;
      };

      desktop = {
        internalMonitor = "eDP-1";
        monitorMode = "2880x1800@120";
        terminal = "ghostty";
        terminalDesktop = "com.mitchellh.ghostty.desktop";
        browser = "zen";
        browserDesktop = "zen.desktop";
        fileManager = "thunar";
        fileManagerDesktop = "thunar.desktop";
        mediaPlayerDesktop = "mpv.desktop";
        defaultWallpaper = "bluehour.jpg";
        screenShareMaxFps = 30;
      };

      hardware.camera = {
        backend = "ipu6";
        platform = "ipu6epmtl";
      };

      keyboards = {
        externalUS = [
          "holtek-usb-hid-keyboard"
          "holtek-usb-hid-keyboard-1"
        ];
      };
    };
  };
}
