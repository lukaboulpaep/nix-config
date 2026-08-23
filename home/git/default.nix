{ userConfig, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = userConfig.fullName;
        email = userConfig.email;
      };

      init.defaultBranch = "main";

      pull.rebase = false;
    };
  };
}
