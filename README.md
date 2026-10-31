# Personal machine configurations

NixOS on a ThinkPad machine, with a shared Home Manager environment and a future `nix-darwin` configuration for a MacBook.

## Layout

- `hosts/`: machine settings and accounts.
- `modules/{nixos,darwin,home-manager}/`: reusable system and application settings.
- `home/luka/`: shared personal settings and per-host additions.
- `lib/inventory.nix`: identity and host metadata.
- `lib/theme.nix`: shared desktop colors, fonts, and geometry.
- `assets/`: fonts, profile pictures, and wallpapers.

## ThinkPad

Keep this repository at `/etc/nixos`; the desktop configuration links directly
to its Hyprland, Quickshell, Neovim, and asset files.

```sh
sudo nixos-rebuild switch --flake .#thinkpad
```

Neovim's `~/.config/nvim` links to `modules/home-manager/neovim/`.
Edit `init.lua` or add Lua modules there, then restart Neovim to load changes.
After the initial rebuild creates the link, configuration edits need no rebuild.

> [!WARNING]
> After rebuilding, you may need to restart your terminal for the SSH agent environment to take effect.

For GitHub SSH, create a key with a passphrase:

```sh
ssh-keygen -t ed25519 -a 100 -C "lukaboulpaep@outlook.com"
cat ~/.ssh/id_ed25519.pub
```

Add the public key to [GitHub](https://github.com/settings/ssh/new), then run
`git push -u origin fresh-start`. The agent remembers the passphrase for the session.

## MacBook

The scaffold is inactive and serves as a placeholder for the future.
