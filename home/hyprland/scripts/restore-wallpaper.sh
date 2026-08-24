#!/usr/bin/env bash

set -euo pipefail

# Aurora Wallpaper Restore

CACHE_FILE="$HOME/.cache/aurora/current-wallpaper"
DEFAULT_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/aurora/default-wallpaper"

# Prefer the saved selection

WALLPAPER=""

if [[ -f "$CACHE_FILE" ]]; then
    WALLPAPER="$(<"$CACHE_FILE")"
fi

# Fall back to the host's default wallpaper

if [[ ! -f "$WALLPAPER" ]] && [[ -f "$DEFAULT_FILE" ]]; then
    DEFAULT_WALLPAPER="$(<"$DEFAULT_FILE")"
    WALLPAPER="$HOME/Wallpapers/$DEFAULT_WALLPAPER"
fi

# Neither the saved selection nor the default is available

if [[ ! -f "$WALLPAPER" ]]; then
    exit 0
fi

# Give the Wayland session / awww daemon a moment

sleep 1

# Restore wallpaper

awww img "$WALLPAPER" \
    --transition-type none \
    >/dev/null 2>&1

# Persist the applied selection so the picker can mark it as selected

mkdir -p "$(dirname "$CACHE_FILE")"
printf '%s\n' "$WALLPAPER" > "$CACHE_FILE"
