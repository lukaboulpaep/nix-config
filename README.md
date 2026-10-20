# Personal machine configurations

NixOS on a ThinkPad machine, with a shared Home Manager environment and a future `nix-darwin` configuration for a MacBook.

## Layout

- `hosts/`: machine settings and accounts.
- `modules/{nixos,darwin,home-manager}/`: reusable system and application settings.
- `home/luka/`: shared personal settings and per-host additions.
- `lib/inventory.nix`: identity and host metadata.
- `assets/`: profile pictures and wallpapers.

## ThinkPad

```sh
sudo nixos-rebuild switch --flake .#thinkpad
```
## MacBook

The scaffold is inactive and serves as a placeholder for the future.
