{
  config,
  inputs,
  lib,
  pkgs,
  userConfig,
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
          "github-cli"
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
    # Install the broker as the normal `pi` command. Naming this
    # `pi-gondolin` allowed the system-level `pi` binary to bypass the host
    # credential setup while still auto-loading the Gondolin extension.
    name = "pi";
    runtimeInputs = [
      pkgs.gh
      pkgs.openssh
    ];
    text = ''
      if [[ -n "''${SSH_AUTH_SOCK:-}" ]]; then
        ssh-add -l >/dev/null 2>&1 || true
      fi

      # Keep the real GitHub token on the host. The Gondolin extension gives
      # the guest a random GH_TOKEN placeholder and substitutes the credential
      # only in requests to the explicitly allowed GitHub hosts.
      if [[ -z "''${PI_GONDOLIN_GITHUB_TOKEN:-}" ]]; then
        github_token="$(${pkgs.gh}/bin/gh auth token --hostname github.com 2>/dev/null || true)"
        if [[ -n "$github_token" ]]; then
          export PI_GONDOLIN_GITHUB_TOKEN="$github_token"
        fi
        unset github_token
      fi

      if [[ -z "''${GONDOLIN_GUEST_DIR:-}" ]]; then
        default_guest_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/pi-gondolin/guest"
        expected_builder=${lib.escapeShellArg "${piGondolinBuildImage}"}
        current_builder=""

        if [[ -r "$default_guest_dir/.nix-builder" ]]; then
          IFS= read -r current_builder < "$default_guest_dir/.nix-builder" || true
        fi

        if [[ ! -f "$default_guest_dir/manifest.json" || "$current_builder" != "$expected_builder" ]]; then
          echo "The managed Gondolin guest image is missing or stale." >&2
          echo "Run nixos-rebuild switch so Home Manager can rebuild it." >&2
          exit 1
        fi

        export GONDOLIN_GUEST_DIR="$default_guest_dir"
      fi

      export PI_GONDOLIN_GIT_USER_NAME=${lib.escapeShellArg userConfig.fullName}
      export PI_GONDOLIN_GIT_USER_EMAIL=${lib.escapeShellArg userConfig.email}

      exec ${pi}/bin/pi -e ${gondolinExtension} "$@"
    '';
  };

  gondolinBuildHostTools = [
    pkgs.bash
    pkgs.coreutils
    pkgs.cpio
    pkgs.e2fsprogs
    pkgs.findutils
    pkgs.lz4
    pkgs.nodejs
    pkgs.which
  ];

  piGondolinBuildImage = pkgs.writeShellApplication {
    name = "pi-gondolin-build-image";
    runtimeInputs = gondolinBuildHostTools;
    text = ''
      required_commands=(cpio debugfs du find lz4 mke2fs node sh which)
      for command in "''${required_commands[@]}"; do
        if ! command -v "$command" >/dev/null 2>&1; then
          echo "Missing Gondolin image-build dependency: $command" >&2
          exit 1
        fi
      done

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

  # The guest image is mutable per-user cache state, so it cannot be linked
  # directly from the Nix store. Rebuild it during Home Manager activation
  # whenever the image builder (including its config and dependencies) changes.
  home.activation.buildGondolinGuestImage = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cache_root=${lib.escapeShellArg "${config.xdg.cacheHome}/pi-gondolin"}
    guest_dir="$cache_root/guest"
    stamp_file="$guest_dir/.nix-builder"
    expected_builder=${lib.escapeShellArg "${piGondolinBuildImage}"}
    current_builder=""

    if [ -r "$stamp_file" ]; then
      IFS= read -r current_builder < "$stamp_file" || true
    fi

    if [ "$current_builder" != "$expected_builder" ] || [ ! -f "$guest_dir/manifest.json" ]; then
      ${pkgs.coreutils}/bin/mkdir -p "$cache_root"
      build_dir="$(${pkgs.coreutils}/bin/mktemp -d "$cache_root/.guest-build.XXXXXX")"
      backup_dir="$cache_root/.guest-previous"

      cleanup_build_dir() {
        if [ -n "''${build_dir:-}" ] && [ -d "$build_dir" ]; then
          ${pkgs.coreutils}/bin/rm -rf "$build_dir"
        fi
      }
      trap cleanup_build_dir EXIT HUP INT TERM

      ${piGondolinBuildImage}/bin/pi-gondolin-build-image "$build_dir"

      if ! ${pkgs.e2fsprogs}/bin/debugfs -R "stat /usr/bin/gh" "$build_dir/rootfs.ext4" 2>/dev/null \
        | ${pkgs.gnugrep}/bin/grep -q '^Inode:'; then
        echo "The Gondolin guest image was built without /usr/bin/gh" >&2
        exit 1
      fi

      printf '%s\n' "$expected_builder" > "$build_dir/.nix-builder"

      ${pkgs.coreutils}/bin/rm -rf "$backup_dir"
      if [ -e "$guest_dir" ] || [ -L "$guest_dir" ]; then
        ${pkgs.coreutils}/bin/mv "$guest_dir" "$backup_dir"
      fi

      if ! ${pkgs.coreutils}/bin/mv "$build_dir" "$guest_dir"; then
        if [ -e "$backup_dir" ] || [ -L "$backup_dir" ]; then
          ${pkgs.coreutils}/bin/mv "$backup_dir" "$guest_dir"
        fi
        exit 1
      fi

      build_dir=""
      ${pkgs.coreutils}/bin/rm -rf "$backup_dir"
      trap - EXIT HUP INT TERM
    fi
  '';
}
