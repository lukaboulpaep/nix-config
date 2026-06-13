# NixOS Configuration

Personal NixOS flake configuration.

## Layout

- `flake.nix` - flake inputs and NixOS configurations
- `hosts/` - host-level system configuration
- `homes/` - Home Manager user configuration
- `modules/nixos/` - reusable NixOS modules
- `modules/home/` - reusable Home Manager modules
- `modules/shared/` - shared data used by hosts and modules

## Hosts

- `hosts/thinkpad/default.nix` - ThinkPad system configuration
- `hosts/thinkpad/hardware-configuration.nix` - generated hardware config
- `hosts/thinkpad/keyboard.nix` - host keyboard selection and built-in keyboard config
- `hosts/thinkpad/monitors.nix` - host monitor names, fallback rules, and lid support

Host files pass machine-specific data into Home Manager through `extraSpecialArgs`.

## Home

- `homes/luka/default.nix` - base user Home Manager configuration
- `homes/luka/hosts/thinkpad.nix` - ThinkPad-specific Home Manager imports

## Hyprland

Hyprland is split between system and user configuration:

- `modules/nixos/wayland/hyprland.nix` enables Hyprland, SDDM, XWayland, and lid policy.
- `modules/home/wayland/hyprland.nix` configures keybindings, inputs, monitor rules, lid handling, and idle locking.

Keyboard profiles are defined as structured data. Host-specific keyboards live in the host keyboard file. Reusable external keyboards live in `modules/shared/keyboards.nix` and are selected per host.

Monitor data is host-specific. The ThinkPad monitor file defines `eDP-1` as the internal panel, a fallback Hyprland monitor rule, and `hasLid = true`.

## Commands

Build the `thinkpad` configuration:

```sh
sudo nixos-rebuild build --flake .#thinkpad
```

Switch to it:

```sh
sudo nixos-rebuild switch --flake .#thinkpad
```
