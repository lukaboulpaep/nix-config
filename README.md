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
