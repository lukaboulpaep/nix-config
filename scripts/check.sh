#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
flake="path:$root"

while IFS= read -r file; do
  nix-instantiate --parse "$root/$file" >/dev/null
done < <(cd "$root" && rg --files -g '*.nix' | sort)

nix flake check "$flake" --no-build

if [[ "${1:-}" == "--build" ]]; then
  nix build "$flake#nixosConfigurations.thinkpad.config.system.build.toplevel" --no-link
fi
