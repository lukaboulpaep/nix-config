.pragma library

function networks(devices) {
    const groups = new Map();
    for (const device of devices) for (const network of device.networks.values) {
        if (!network.name) continue;
        const key = network.name + "\u0000" + network.security;
        const current = groups.get(key);
        if (!current || (network.connected && !current.connected)
            || (!current.connected && (network.stateChanging || network.signalStrength > current.signalStrength)))
            groups.set(key, network);
    }
    return Array.from(groups.values()).sort((a, b) => Number(b.connected) - Number(a.connected)
        || Number(b.known) - Number(a.known) || b.signalStrength - a.signalStrength || a.name.localeCompare(b.name));
}

function passwordValid(value, sae) {
    return sae ? value.length >= 1 && value.length <= 63
        : (value.length >= 8 && value.length <= 63) || /^[0-9a-fA-F]{64}$/.test(value);
}

function strength(value) {
    return value >= 0.75 ? "Strong signal" : value >= 0.5 ? "Good signal" : value >= 0.25 ? "Fair signal" : "Weak signal";
}

function wifiIcon(value) {
    return value >= 0.75 ? "󰤨" : value >= 0.5 ? "󰤥" : value >= 0.25 ? "󰤢" : "󰤟";
}

function bluetoothName(device) {
    for (const value of [device.name, device.deviceName]) {
        const name = (value || "").trim();
        if (name && !/^(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}$/i.test(name)
            && !/^[0-9a-f]{12}$/i.test(name)) return name;
    }
    return "";
}

function bluetoothLabel(device) {
    return bluetoothName(device) || ({
        "audio-headset": "Unnamed headset", "audio-headphones": "Unnamed headphones",
        "audio-card": "Unnamed audio device", "input-keyboard": "Unnamed keyboard",
        "input-mouse": "Unnamed mouse", "input-gaming": "Unnamed controller",
        "phone": "Unnamed phone", "computer": "Unnamed computer"
    })[device.icon] || "Unnamed device";
}
