# Personal machine configurations

One flake for the ThinkPad (NixOS) and a future MacBook (nix-darwin),
with a shared personal environment managed by Home Manager.

## Layout

```text
flake.nix                       Inputs, host outputs, Home Manager integration
flake.lock                      Exact dependency revisions
hosts/
  thinkpad/
    configuration.nix           ThinkPad settings and account
    hardware-configuration.nix  Generated disk and hardware settings
  macbook/
    configuration.nix           MacBook settings and existing account integration
modules/
  nixos/base.nix                Baseline for NixOS hosts
  darwin/base.nix               Baseline for macOS hosts
  darwin/homebrew.nix           Native application integration (currently disabled)
  home-manager/development.nix  Shared personal development packages
home/luka/
  default.nix                   Shared personal environment
  thinkpad.nix                  ThinkPad home directory and personal additions
  macbook.nix                   MacBook home directory and personal additions
lib/inventory.nix               Shared identity and explicit host metadata
assets/                        Profile pictures and wallpapers
```

Each host imports its platform baseline explicitly. The inventory selects its
login name and Home Manager entry point. Both home entry points import
`home/luka/default.nix`, which selects reusable Home Manager modules.

NixOS and nix-darwin modules use different option sets. Share personal application
settings through Home Manager; keep operating-system settings in their respective
platform directories. There is no automatic directory importing.

## Making changes

- Machine-specific system settings and account permissions: `hosts/<host>/configuration.nix`.
- Settings wanted on every host of one OS: `modules/nixos/base.nix` or `modules/darwin/base.nix`.
- Shared personal tools: `modules/home-manager/development.nix`.
- Personal application configuration: add modules such as `modules/home-manager/git.nix`,
  `shell.nix`, `neovim/default.nix`, or `pi.nix`, and import them from `home/luka/default.nix`.
- Personal settings for one machine: `home/luka/<host>.nix`.
- Shared identity and each host's login name, architecture, and entry points: `lib/inventory.nix`.

Keep larger application source files beside their module, for example
`modules/home-manager/neovim/config/init.lua`. The existing images stay in
`assets/`; storing them there does not apply them automatically.

Only create `packages/` when defining custom software builds, `overlays/` when
modifying the package collection, and `secrets/` when adding encrypted secrets.

Git, curl, and nano remain system-wide on the ThinkPad for recovery and root use.
Codex is installed for the configured user through Home Manager. Existing Zsh
dotfiles and editor settings are not managed by this initial configuration.

## ThinkPad

After adding new source files to Git's index, evaluate/build before switching:

```sh
git add flake.nix flake.lock hosts modules home lib README.md
nix flake check --no-build
sudo nixos-rebuild build --flake .#thinkpad
sudo nixos-rebuild switch --flake .#thinkpad
```

Home Manager is integrated into the system rebuild. A separate `home-manager switch`
is not needed. `result` is build output and is not part of the source layout.

## Preparing the MacBook

The MacBook files are a scaffold, and `darwinHosts` is initially empty.
To activate it, uncomment the `macbook` inventory entry and confirm:

1. Architecture: `aarch64-darwin` for Apple Silicon or `x86_64-darwin` for Intel.
2. `userName`: the existing macOS short login name, including its capitalization.
3. Desired hostname, timezone, and initial nix-darwin state version.
4. How Nix was installed: the baseline assumes nix-darwin manages Nix settings.
   Installations that manage Nix themselves may require `nix.enable = false` and
   removing `nix.settings` from the Darwin baseline.

Install Nix and bootstrap nix-darwin on that Mac, then use its rebuild command:

```sh
darwin-rebuild build --flake .#macbook
sudo darwin-rebuild switch --flake .#macbook
```

Homebrew integration remains disabled until Homebrew is installed and native
applications are selected. No Neovim, Pi, desktop environment, or shell dotfile
configuration is enabled just to populate the suggested folder structure.
