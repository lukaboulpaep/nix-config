{ codex, user, ... }:
{
  home.packages = [ codex ];

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
