# NixOS configuration

Luka's modular, inventory-driven NixOS configuration. The current flake targets NixOS/Home Manager/Stylix `26.05` and builds the `thinkpad` host.

## Inventory model

`lib/inventory.nix` is the source of truth for people and machines:

- `users` defines identity, login shell, email, and Home Manager profiles such as `personal`.
- `hosts` defines the users present on a device, locale, desktop defaults, keyboards, monitors, hardware details, and feature flags.
- Feature flags decide whether a host receives desktop, audio, Bluetooth, battery/lid, Intel graphics, camera, DDC brightness, and container configuration.

Adding a server therefore does not implicitly enable Bluetooth, a graphical shell, or laptop power services. Adding another user profile does not require copying the personal Home Manager configuration.

## Layout

```text
.
├── flake.nix
├── lib/
│   ├── inventory.nix       # hosts, users, profiles, hardware facts, and capabilities
│   └── themes.nix          # Aurora UI/theme database
├── hosts/thinkpad/         # ThinkPad composition and generated hardware
├── modules/                # reusable NixOS feature modules
├── home/
│   ├── default.nix         # shared Home Manager configuration
│   ├── profiles/           # user/profile-specific application selections
│   ├── hyprland/           # host-aware Lua compositor configuration
│   ├── quickshell/         # bar, popups, launcher, OSD, wallpaper picker, notifications
│   ├── pi/                 # Pi/Gondolin Home Manager integration
│   └── theme/              # Aurora and Starship theme generation
└── scripts/check.sh        # parse, evaluate, and optional build checks
```

## ThinkPad selections

- User and shell: `luka`, Zsh with Starship
- Desktop: SDDM + UWSM + Hyprland
- Shell UI: Quickshell
- Theme: Stylix plus Aurora-generated UI assets
- Terminal: Ghostty
- Browser: Zen Browser
- File manager: Thunar
- Media player: MPV
- Editor: Neovim; project flakes provide language servers and toolchains
- Agent tools: Codex, Herdr, Pi, and KVM-backed `pi-gondolin`
- Containers: Podman with Docker CLI/socket compatibility and `podman-compose`
- Hardware: Intel graphics, IPU6 camera, Bluetooth, battery/lid services, DDC brightness, encrypted Btrfs

The personal profile includes AWS Vault, Bruno, GitHub CLI, LazyGit, Ghostty, MPV, 1Password, Zed, Zen Browser, and the Cider Flatpak.

The configuration intentionally avoids Obsidian, Kitty, Fastfetch, global project language toolchains, monitoring suites, gaming/content-creation suites, Docker Engine, libvirt-managed VMs, and NVIDIA/CUDA/PRIME configuration.

## Why the supporting desktop modules exist

- Thunar is the graphical file manager.
- GVfs supplies trash and virtual/network filesystems; UDisks2 handles removable disks; Tumbler generates thumbnails; XFConf persists Thunar settings.
- Polkit authorizes privileged actions requested by graphical programs. The KDE agent displays authentication prompts.
- XDG portals and MIME settings provide file pickers, screen sharing, screenshots, application launchers, notification portal wiring, and default-application handling.
- NetworkManager manages Wi-Fi and Ethernet and supplies data to Quickshell. No inbound SSH server is enabled.
- UPower and power-profiles-daemon expose battery and performance state to Quickshell. These modules are selected only for battery-capable hosts.
- IPU6 camera support and video group membership are selected only for camera-capable hosts.
- DDC/I2C brightness support is selected only for hosts that opt into it.
- Session variables enable native Wayland behavior for Mozilla and Electron applications without forcing every toolkit away from its own fallback logic.
- Podman is host infrastructure; project flakes can still pin project-specific CLIs and dependencies because `nix develop` controls each project shell's `PATH`.
- Pi keeps its Node/npm runtime scoped to the Pi wrappers instead of exposing Node as a general development tool.

## Validation

```sh
./scripts/check.sh
./scripts/check.sh --build
```

The first command parses every Nix file and runs `nix flake check --no-build`. The second also builds the complete ThinkPad system without activating it.

After reviewing a successful build:

```sh
sudo nixos-rebuild test --flake "path:$PWD#thinkpad"
sudo nixos-rebuild switch --flake "path:$PWD#thinkpad"
```
