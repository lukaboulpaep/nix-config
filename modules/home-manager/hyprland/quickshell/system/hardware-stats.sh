#!/usr/bin/env bash
# Optional hardware is discovered by capability, not by the current machine.
export LC_ALL=C
shopt -s nullglob
for monitor in /sys/class/hwmon/hwmon*; do
    IFS= read -r name < "$monitor/name" || continue
    for input in "$monitor"/temp*_input; do
        IFS= read -r value < "$input" 2>/dev/null || continue
        label=""
        label_file="${input%_input}_label"
        if [[ -r "$label_file" ]]; then IFS= read -r label < "$label_file"; fi
        [[ "$value" =~ ^-?[0-9]+$ ]] && printf 'temperature\t%s\t%s\t%s\n' "$name" "$label" "$value"
    done
    for input in "$monitor"/fan*_input; do
        IFS= read -r value < "$input" 2>/dev/null || continue
        [[ "$value" =~ ^[0-9]+$ ]] && printf 'fan\t%s\t%s\n' "$name" "$value"
    done
done
for card in /sys/class/drm/card[0-9]*; do
    [[ "${card##*/}" =~ ^card[0-9]+$ ]] || continue
    [[ -r "$card/device/gpu_busy_percent" ]] || continue
    IFS= read -r value < "$card/device/gpu_busy_percent" || continue
    [[ "$value" =~ ^[0-9]+$ ]] && printf 'gpu\t%s\t%s\n' "${card##*/}" "$value"
done
exit 0
