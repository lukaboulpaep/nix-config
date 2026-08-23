{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;

    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Keep Neovim itself lightweight.
    withNodeJs = false;
    withPython3 = false;
    withRuby = false;

    plugins = with pkgs.vimPlugins; [
      # Completion

      blink-cmp

      # LSP / Code intelligence

      nvim-lspconfig

      # Syntax / Treesitter

      nvim-treesitter.withAllGrammars
      nvim-colorizer-lua

      # Search / Navigation

      telescope-nvim
      plenary-nvim
      nvim-web-devicons

      # Git

      gitsigns-nvim

      # Formatting / Linting

      conform-nvim
      nvim-lint

      # UI

      which-key-nvim
      lualine-nvim
      snacks-nvim

      # File Manager
      nvim-tree-lua

      # Dashboard
      alpha-nvim
    ];

    # Language servers, formatters, compilers, and debuggers come from each
    # project's dev shell, so their versions follow the project flake.
    extraPackages = [ ];
  };

  xdg.configFile."nvim".source = ./config;
}
