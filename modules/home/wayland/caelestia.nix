{ inputs, pkgs, ... }:

let
  caelestiaPackage = inputs.caelestia-shell.packages.${pkgs.stdenv.hostPlatform.system}.with-cli;
  caelestiaWithoutSessionGif = caelestiaPackage.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.perl ];
    postPatch = (oldAttrs.postPatch or "") + ''
      perl -0pi -e 's/\n    AnimatedImage \{.*?fillMode: AnimatedImage\.PreserveAspectFit\n    \}\n//s' modules/session/Content.qml
    '';
  });
in
{
  imports = [
    inputs.caelestia-shell.homeManagerModules.default
  ];

  programs.caelestia = {
    package = caelestiaWithoutSessionGif;
    systemd = {
      enable = true;
      target = "graphical-session.target";
      environment = [ ];
    };
    enable = true;
    cli.enable = true;
  };
}
