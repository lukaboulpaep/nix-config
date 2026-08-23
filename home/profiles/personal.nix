{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  home.packages = with pkgs; [
    aws-vault
    bruno
    gh
    ghostty
    lazygit
    mpv
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    _1password-gui
    zed-editor
  ];

  services.flatpak = {
    enable = true;
    packages = [
      {
        appId = "sh.cider.Cider";
        origin = "flathub";
      }
    ];
  };
}
