{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  piUnwrapped = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi.override {
    useBun = false;
  };

  # Pi invokes npm when synchronizing packages from settings.json. Keep that
  # runtime dependency on Pi's PATH without making Node a general profile tool.
  pi = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [ pkgs.nodejs ];
    text = ''
      exec ${piUnwrapped}/bin/pi "$@"
    '';
  };

  gondolinGuestArch =
    if pkgs.stdenv.hostPlatform.isAarch64 then
      "aarch64"
    else if pkgs.stdenv.hostPlatform.isx86_64 then
      "x86_64"
    else
      throw "Gondolin does not support ${pkgs.stdenv.hostPlatform.system}";

  gondolinBuildConfig = pkgs.writeText "pi-gondolin-build-config.json" (
    builtins.toJSON {
      arch = gondolinGuestArch;
      distro = "alpine";
      alpine = {
        version = "3.23.0";
        kernelPackage = "linux-virt";
        kernelImage = "vmlinuz-virt";
        rootfsPackages = [
          "linux-virt"
          "rng-tools"
          "bash"
          "ca-certificates"
          "curl"
          "e2fsprogs"
          "nodejs"
          "npm"
          "uv"
          "python3"
          "openssh"
          "git"
          "nix"
          "jq"
          "ripgrep"
        ];
        initramfsPackages = [ ];
        krunfwVersion = "v5.2.1";
      };
      rootfs.label = "gondolin-root";
      runtimeDefaults.rootfsMode = "cow";
    }
  );

  piGondolin = pkgs.writeShellApplication {
    name = "pi-gondolin";
    runtimeInputs = [ pkgs.openssh ];
    text = ''
      if [[ -n "''${SSH_AUTH_SOCK:-}" ]]; then
        ssh-add -l >/dev/null 2>&1 || true
      fi

      default_guest_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/pi-gondolin/guest"
      if [[ -z "''${GONDOLIN_GUEST_DIR:-}" && -f "$default_guest_dir/manifest.json" ]]; then
        export GONDOLIN_GUEST_DIR="$default_guest_dir"
      fi

      exec ${pi}/bin/pi -e ${gondolinExtension} "$@"
    '';
  };

  piGondolinBuildImage = pkgs.writeShellApplication {
    name = "pi-gondolin-build-image";
    runtimeInputs = [
      pkgs.cpio
      pkgs.e2fsprogs
      pkgs.lz4
      pkgs.nodejs
    ];
    text = ''
      output="''${1:-''${XDG_CACHE_HOME:-$HOME/.cache}/pi-gondolin/guest}"
      mkdir -p "$(dirname "$output")"
      exec ${pkgs.nodejs}/bin/node \
        ${gondolinExtension}/node_modules/@earendil-works/gondolin/dist/bin/gondolin.js \
        build --config ${gondolinBuildConfig} --output "$output"
    '';
  };

  gondolinExtension = pkgs.buildNpmPackage {
    pname = "pi-extension-gondolin";
    inherit (piUnwrapped) version;

    # home/pi mirrors ~/.pi. Include only the checked-in extension sources so
    # a local node_modules used for TypeScript tooling cannot enter the build.
    src = lib.fileset.toSource {
      root = ./agent/extensions/gondolin;
      fileset = lib.fileset.unions [
        ./agent/extensions/gondolin/index.ts
        ./agent/extensions/gondolin/package.json
        ./agent/extensions/gondolin/package-lock.json
      ];
    };

    npmDepsHash = "sha256-sQTfKtegh1HloK9zxlbYkJb3vW7yBfYYM8DYFu2oHZc=";
    npmFlags = [ "--ignore-scripts" ];
    dontNpmBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -R index.ts package.json package-lock.json node_modules "$out/"

      runHook postInstall
    '';
  };
in
{
  home.packages = [
    piGondolin
    piGondolinBuildImage
  ];

  # Pi installs pinned package specs from settings into its managed npm area on
  # first startup. Version 30.0.0 was reviewed from pi-packages-main.zip
  # (SHA-256 311ce141217f54fc8a219fbfa4f67e4ac174823178f6041d2a42595b94ec9e63).
  # The package remains host-side trusted code; only its policy is stored under
  # extensions/pi-permission-system.
  home.file.".pi/agent/settings.json".text = builtins.toJSON {
    packages = [ "npm:@gotgenes/pi-permission-system@30.0.0" ];
  };

  home.file.".pi/agent/extensions/gondolin".source = gondolinExtension;
  home.file.".pi/agent/extensions/pi-permission-system/config.json".source =
    ./agent/extensions/pi-permission-system/config.json;
}
