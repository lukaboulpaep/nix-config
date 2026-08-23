# Repository instructions

## Architecture

- `lib/inventory.nix` is the source of truth for users, hosts, hardware capabilities, regional settings, and desktop application commands.
- A host opts into capabilities through `features`. Do not enable laptop, Bluetooth, graphics, desktop, or container settings globally when they can be selected per host.
- `hosts/<name>/default.nix` composes reusable NixOS modules; generated storage and detected hardware stay in that host's `hardware-configuration.nix`.
- `modules/<feature>/` owns system services and packages. Modules must consume `hostConfig` rather than hard-code a current hostname, username, GPU, display, or keyboard.
- `home/default.nix` contains shared Home Manager behavior. `home/profiles/<profile>.nix` contains user/profile-specific applications. A host selects users, and each user selects profiles in the inventory.
- Project-specific languages, compilers, language servers, formatters, and debuggers belong in project flakes, not the system or Home Manager profile.

## Desktop

- The desktop uses Hyprland Lua, Quickshell, and the Aurora theme database from the upstream `subha279/NixOS` design.
- Keep host-dependent Hyprland variables, monitor rules, and keyboard devices generated from `hostConfig` in `home/hyprland/default.nix`.
- Quickshell owns the bar, popups, launcher, wallpaper picker, OSD, and notification server. Do not add another notification daemon or D-Bus owner for `org.freedesktop.Notifications`.
- Keep QML separated into `core/`, `services/`, `components/`, and `modules/`. Hardware/process integration belongs in services; reusable presentation belongs in components.
- Hyprland layer and window rules should refer only to applications actually retained by the configuration.
- Runtime dependencies must be declared in Nix. Graphical services must follow `graphical-session.target` and guard on `WAYLAND_DISPLAY` where required.

## Hardware and safety

- This ThinkPad is Intel-only. Do not introduce NVIDIA, CUDA, PRIME bus IDs, or `nvidia-offload` configuration without a new verified host that declares that hardware.
- Preserve the ThinkPad's generated LUKS, Btrfs, EFI, CPU, initrd, and device UUID settings.
- Do not bump `system.stateVersion` or `home.stateVersion` during normal upgrades.
- Do not commit private keys, credentials, `.env` files, generated build results, or editor state.
- Podman is the selected container runtime. Do not add Docker Engine or the libvirt/QEMU VM stack unless explicitly requested.

## Validation

- Parse every changed Nix file with `nix-instantiate --parse`.
- Run `nix flake check "path:$PWD" --no-build` after module or flake changes.
- Run `./scripts/check.sh --build` for a complete ThinkPad build when inputs are available.
- Test before switching; never use `nixos-rebuild switch` merely as validation.
