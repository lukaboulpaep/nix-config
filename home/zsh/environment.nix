{
  hostConfig,
  lib,
  ...
}:

{
  # Shell Environment

  home.sessionVariables = {

    # Pager

    PAGER = "less";

    LESS = "-R";

  }
  // lib.optionalAttrs hostConfig.features.desktop {
    BROWSER = hostConfig.desktop.browser;
    TERMINAL = hostConfig.desktop.terminal;
  };

  # User PATH

  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
