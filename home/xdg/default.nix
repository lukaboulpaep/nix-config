{ hostConfig, ... }:

let
  archive = hostConfig.desktop.archiveManagerDesktop;
in
{
  xdg = {
    enable = true;

    userDirs = {
      enable = true;
      createDirectories = true;
    };

    # User MIME associations take precedence over system defaults. Keep archives
    # out of the browser so opening a completed download cannot start a
    # browser/download loop.
    mimeApps = {
      enable = true;

      defaultApplications = {
        "application/zip" = [ archive ];
        "application/x-zip-compressed" = [ archive ];
        "application/x-7z-compressed" = [ archive ];
        "application/x-tar" = [ archive ];
        "application/gzip" = [ archive ];
        "application/x-xz" = [ archive ];
        "application/vnd.rar" = [ archive ];
      };
    };
  };
}
