.pragma library

function duration(seconds) {
    if (!Number.isFinite(seconds) || seconds <= 0) return "";
    const minutes = Math.max(1, Math.round(seconds / 60));
    const hours = Math.floor(minutes / 60);
    return hours ? hours + "h" + (minutes % 60 ? " " + minutes % 60 + "m" : "") : minutes + " min";
}

function health(batteries) {
    if (!batteries.length || batteries.some(b => !b.healthSupported || !Number.isFinite(b.healthPercentage))) return -1;
    if (batteries.length === 1) return Math.max(0, Math.min(100, batteries[0].healthPercentage));
    let capacity = 0, design = 0;
    for (const battery of batteries) {
        if (battery.energyCapacity <= 0 || battery.healthPercentage <= 0) return -1;
        capacity += battery.energyCapacity;
        design += battery.energyCapacity * 100 / battery.healthPercentage;
    }
    return design > 0 ? Math.min(100, capacity / design * 100) : -1;
}

function parseProfiles(text) {
    const profiles = [];
    let active = "", current = null;
    for (const line of text.split("\n")) {
        const heading = line.match(/^\s*(\*)?\s*(power-saver|balanced|performance):\s*$/);
        if (heading) {
            current = { id: heading[2], degraded: "" };
            profiles.push(current);
            if (heading[1]) active = heading[2];
        } else if (current) {
            const degradation = line.match(/^\s*Degraded:\s*(.+)$/i);
            if (degradation && degradation[1].trim() !== "no") current.degraded = degradation[1].trim();
        }
    }
    return { profiles: profiles, active: active };
}

function profileName(id) {
    return ({"power-saver": "Power saver", "balanced": "Balanced", "performance": "Performance"})[id] || id;
}
