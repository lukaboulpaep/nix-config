.pragma library

function focusRequest(entry) {
    const key = entry.key.replace(/[\\"\x00-\x1f]/g,
        c => "\\" + String(c.charCodeAt(0)).padStart(3, "0"));
    return 'hl.dsp.focus({ workspace = "' + key + '", on_current_monitor = false })';
}

function entries(live, monitors, mainMonitor, assignments) {
    const byId = new Map(live.filter(ws => ws.id > 0 || (ws.name && !ws.name.startsWith("special:")))
        .map(ws => [ws.id, ws]));
    const ids = new Set(Array.from({length: 10}, (_, i) => i + 1));
    for (const id of byId.keys()) ids.add(id);
    return Array.from(ids).sort((a, b) => (a > 0 ? a : Infinity) - (b > 0 ? b : Infinity)
        || (byId.get(a)?.name || "").localeCompare(byId.get(b)?.name || "")).map(id => {
        const ws = byId.get(id);
        const key = id > 0 ? String(id) : "name:" + ws.name;
        // Live ownership wins over a saved placement immediately after a move.
        const owner = ws?.monitor || assignments[key] || mainMonitor;
        return {id: id, key: key, label: id > 0 ? String(id) : ws.name, monitor: owner,
            current: monitors.some(m => m.name === owner && m.activeWorkspace === id),
            windowCount: ws?.windowCount || 0};
    });
}
