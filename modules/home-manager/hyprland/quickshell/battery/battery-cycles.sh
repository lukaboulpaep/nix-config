#!/usr/bin/env bash
shopt -s nullglob
for battery in /sys/class/power_supply/*; do
    IFS= read -r type < "$battery/type" 2>/dev/null || continue
    [[ "$type" == "Battery" && -r "$battery/cycle_count" ]] || continue
    scope=""
    if [[ -r "$battery/scope" ]]; then IFS= read -r scope < "$battery/scope"; fi
    [[ "$scope" == "Device" ]] && continue
    IFS= read -r cycles < "$battery/cycle_count" 2>/dev/null || continue
    [[ "$cycles" =~ ^[0-9]+$ ]] && printf '%s\t%s\n' "${battery##*/}" "$cycles"
done
exit 0
