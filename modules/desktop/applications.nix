{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [

    # File Manager

    # thunar, thunar-volman and tumbler are provided by programs.thunar / services.tumbler in ./services.nix, and gvfs by services.gvfs.
    ffmpegthumbnailer

    # Archives

    p7zip
    unar

    # Archive Manager
    file-roller

    # Audio

    pavucontrol

    # Theming

    nwg-look

    # Network

    networkmanagerapplet

    # Screenshots

    grim
    slurp
    swappy

    # Image Viewer

    kdePackages.gwenview

    # Authentication

    kdePackages.polkit-kde-agent-1

    # Wallpaper

    awww

  ];
}
