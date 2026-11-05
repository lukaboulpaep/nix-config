{ config, lib, pkgs, neovim, ... }:
let
  # Parsers and their matching queries are compiled/pinned together by Nix.
  treesitter = pkgs.vimPlugins.nvim-treesitter.withPlugins (p: with p; [
    bash css go gomod gosum gowork hcl html javascript json lua luadoc
    markdown markdown_inline nix python qmljs query terraform tsx typescript
    vim vimdoc yaml
  ]);
  withDependencies = plugin: [ plugin ] ++ lib.concatMap withDependencies (plugin.dependencies or [ ]);
  treesitterRuntime = pkgs.symlinkJoin {
    name = "neovim-treesitter-runtime";
    paths = lib.unique (lib.concatMap withDependencies treesitter.dependencies);
  };
in
{
  home.packages = [
    neovim
    # Available for editing the editor configuration outside a project shell.
    # Project-specific servers belong in each project's devShell instead.
    pkgs.lua-language-server
    pkgs.nixd
    pkgs.nixfmt
    pkgs.ripgrep
    pkgs.fd
    (pkgs.writeShellScriptBin "v" ''
      exec ${neovim}/bin/nvim "$@"
    '')
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    # Native Wayland clipboard access for yanks and exported review comments.
    pkgs.wl-clipboard
  ];

  home.sessionVariables.EDITOR = "nvim";

  xdg.dataFile."nvim/site/parser".source = "${treesitterRuntime}/parser";
  xdg.dataFile."nvim/site/queries".source = "${treesitterRuntime}/queries";

  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "/etc/nixos/modules/home-manager/neovim";
}
