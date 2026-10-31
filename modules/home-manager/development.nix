{
  codex,
  pkgs,
  user,
  ...
}:
{
  home.packages = [
    codex
    pkgs.lazygit
  ];

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = user.fullName;
        email = user.email;
      };
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      fetch.prune = true;
      pull.ff = "only";
    };
  };
}
