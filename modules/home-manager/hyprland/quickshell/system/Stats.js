.pragma library

function cpuSnapshot(text) {
    const result = {};
    for (const line of text.split("\n")) {
        if (!/^cpu(?:\d+)?\s/.test(line)) continue;
        const fields = line.trim().split(/\s+/);
        const values = fields.slice(1, 9).map(Number); // Guest time is already included.
        if (values.length < 4 || values.some(v => !Number.isFinite(v))) continue;
        result[fields[0]] = { total: values.reduce((a, b) => a + b, 0), idle: values[3] + (values[4] || 0) };
    }
    return result;
}

function cpuUsage(previous, current) {
    if (!previous || !current || current.total <= previous.total || current.idle < previous.idle) return -1;
    return Math.max(0, Math.min(100, 100 * (1 - (current.idle - previous.idle) / (current.total - previous.total))));
}

function memorySnapshot(text) {
    const values = {};
    for (const line of text.split("\n")) {
        const match = line.match(/^(\w+):\s+(\d+)/);
        if (match) values[match[1]] = Number(match[2]) * 1024;
    }
    if (!(values.MemTotal > 0) || values.MemAvailable === undefined) return null;
    const used = Math.max(0, values.MemTotal - values.MemAvailable);
    return { total: values.MemTotal, used: used, percent: 100 * used / values.MemTotal,
        swapTotal: values.SwapTotal || 0, swapUsed: Math.max(0, (values.SwapTotal || 0) - (values.SwapFree || 0)) };
}

function appendSample(samples, value, now) {
    const recent = samples.filter(p => p.time >= now - 120000);
    // A pause or resume is a gap, not a continuous line through unobserved time.
    if (recent.length && now - recent[recent.length - 1].time > 6000) recent.push({time: now - 1, value: -1});
    recent.push({ time: now, value: value });
    return recent.slice(-122);
}

function networkSnapshot(text) {
    const result = {};
    for (const line of text.split("\n")) {
        const match = line.match(/^\s*([^:]+):\s*(.*)$/);
        if (!match || match[1] === "lo") continue;
        const fields = match[2].trim().split(/\s+/).map(Number);
        if (fields.length >= 16) result[match[1]] = { rx: fields[0], tx: fields[8] };
    }
    return result;
}

function networkRate(previous, current, seconds) {
    if (!previous || !current || seconds <= 0 || seconds > 6 || current.rx < previous.rx || current.tx < previous.tx)
        return { rx: -1, tx: -1 };
    return { rx: (current.rx - previous.rx) / seconds, tx: (current.tx - previous.tx) / seconds };
}

function defaultInterface(text, ipv6) {
    let best = "", metric = Infinity;
    for (const line of text.trim().split("\n")) {
        const fields = line.trim().split(/\s+/);
        if (ipv6) {
            if (fields.length < 10 || fields[0] !== "00000000000000000000000000000000" || fields[1] !== "00") continue;
            const priority = parseInt(fields[5], 16), flags = parseInt(fields[8], 16), name = fields[9];
            if ((flags & 1) && name !== "lo" && priority < metric) { best = name; metric = priority; }
        } else {
            if (fields.length < 8 || fields[1] !== "00000000" || !(parseInt(fields[3], 16) & 1)) continue;
            const priority = Number(fields[6]);
            if (priority < metric) { best = fields[0]; metric = priority; }
        }
    }
    return best;
}

function bytes(value, decimals) {
    if (!Number.isFinite(value) || value < 0) return "—";
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let unit = 0;
    while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit++; }
    return value.toFixed(unit === 0 ? 0 : (decimals === undefined ? 1 : decimals)) + " " + units[unit];
}

function uptime(seconds) {
    if (seconds < 0) return "—";
    const minutes = Math.floor(seconds / 60), hours = Math.floor(minutes / 60), days = Math.floor(hours / 24);
    return days ? days + "d " + hours % 24 + "h" : hours ? hours + "h " + minutes % 60 + "m" : minutes + "m";
}
