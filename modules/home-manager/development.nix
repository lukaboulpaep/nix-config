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

  home.file.".codex/AGENTS.md".source = ./agents/AGENTS.md;

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
