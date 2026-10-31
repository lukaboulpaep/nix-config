# Run under the quickshell user service. Restart the whole process when
# NetworkManager changes its D-Bus owner: QML reloads retain the stale backend.
network_owner() {
    busctl --system --timeout=2 call org.freedesktop.DBus /org/freedesktop/DBus \
        org.freedesktop.DBus GetNameOwner s org.freedesktop.NetworkManager 2>/dev/null || true
}

initial_owner=$(network_owner)
quickshell --no-duplicate &
bar_pid=$!

while kill -0 "$bar_pid" 2>/dev/null; do
    sleep 5
    current_owner=$(network_owner)
    # Wait for NetworkManager to return before restarting the bar.
    if [[ -n "$current_owner" && "$current_owner" != "$initial_owner" ]]; then
        echo "NetworkManager restarted; refreshing the bar's network backend."
        exit 1
    fi
done

wait "$bar_pid"
