# NixOS Configuration

Personal NixOS flake configuration.

## Layout

- `flake.nix` - flake inputs and NixOS configurations
- `systems/` - host-level system configuration
- `homes/` - Home Manager user configuration

## Usage

Build the `thinkpad` configuration:

```sh
sudo nixos-rebuild build --flake .#thinkpad
```

Switch to it:

```sh
sudo nixos-rebuild switch --flake .#thinkpad
```
