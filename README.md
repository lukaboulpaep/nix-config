# NixOS configuration

A multi-host, multi-user NixOS configuration.

## Inventory model

`lib/inventory.nix` separates people from machines:

- `users` defines identity, login shell, and Home Manager profiles such as `personal` or a future `work` profile.
- `hosts` defines the users present on a device, regional settings, desktop commands, keyboards, monitors, and feature flags.
- Feature flags decide whether a host receives desktop, audio, Bluetooth, battery/lid, Intel graphics, and container configuration.

Adding a server therefore does not implicitly enable Bluetooth, a graphical shell, or laptop power services. Adding a work account does not require copying the personal Home Manager configuration.

## Layout

```text
.
├── flake.nix
├── lib/
│   ├── inventory.nix       # hosts, users, profiles, and capabilities
│   └── themes.nix          # Aurora UI/theme database
├── hosts/thinkpad/         # ThinkPad composition and generated hardware
├── modules/                # reusable NixOS feature modules
├── home/
│   ├── default.nix         # shared Home Manager configuration
│   ├── profiles/           # personal/work application selections
│   ├── hyprland/           # modular Lua compositor configuration
│   ├── quickshell/         # bar, popups, launcher, and notifications
│   └── theme/              # Aurora and Starship theme generation
└── scripts/check.sh        # parse, evaluate, and optional build checks
```

## ThinkPad selections

- User and shell: `luka`, Zsh with Starship
- Desktop: SDDM + UWSM + Hyprland
- Shell UI: Quickshell
- Terminal: Ghostty
- Browser: Zen Browser
- File manager: Thunar
- Media player: MPV
- Editor: Neovim; project flakes provide language servers and toolchains
- Containers: Podman with Docker CLI compatibility
- Hardware: Intel graphics, Bluetooth, battery/lid, encrypted Btrfs

The personal profile retains AWS Vault, Bruno, GitHub CLI, LazyGit, Ghostty, MPV, 1Password, Zed, Zen Browser, and the Cider Flatpak. It intentionally excludes Obsidian, Kitty, Fastfetch, coding agents, global language toolchains, monitoring suites, gaming, content-creation suites, libvirt/QEMU, and NVIDIA configuration.

## Why the supporting desktop modules exist

- Thunar is the graphical file manager.
- GVfs supplies trash and virtual/network filesystems; UDisks2 handles removable disks; Tumbler generates thumbnails; XFConf persists Thunar settings.
- Polkit authorizes privileged actions requested by graphical programs. The KDE agent displays the authentication prompt.
- XDG portals and MIME settings provide file pickers, screen sharing, screenshots, application launchers, and default-application handling.
- NetworkManager manages Wi-Fi and Ethernet and supplies data to Quickshell. No inbound SSH server is enabled.
- UPower and power-profiles-daemon expose battery and performance state to Quickshell. These modules are selected only for battery-capable hosts.
- Session variables enable native Wayland behavior for Mozilla and Electron applications without forcing every toolkit away from its own fallback logic.
- Podman is host infrastructure; project flakes can still pin project-specific CLIs and dependencies because `nix develop` controls the project shell's `PATH`.

## Validation

```sh
./scripts/check.sh
./scripts/check.sh --build
```

The first command parses all Nix files and evaluates the flake. The second also builds the complete ThinkPad system without activating it.

After reviewing a successful build:

```sh
sudo nixos-rebuild test --flake "path:$PWD#thinkpad"
sudo nixos-rebuild switch --flake "path:$PWD#thinkpad"
```
