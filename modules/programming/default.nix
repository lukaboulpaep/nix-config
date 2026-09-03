{
  hostConfig,
  inputs,
  pkgs,
  ...
}:

let
  # The default llm-agents.nix build is a Bun-compiled executable. Gondolin
  # relies on Node's net implementation, so keep Pi on its supported Node
  # entry point instead.
  piUnwrapped = inputs.llm-agents.packages.${hostConfig.system}.pi.override { useBun = false; };

  # Pi installs packages declared in its settings into a managed npm directory
  # at runtime. Scope Node and npm to Pi instead of exposing them as general
  # system development tools.
  pi = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec ${piUnwrapped}/bin/pi "$@"
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.codex
    inputs.herdr.packages.${hostConfig.system}.herdr
    pi
  ];
}
