.pragma library

function applications(streams) {
    const groups = new Map();
    for (const node of streams) {
        const props = node.properties || {};
        const name = props["application.name"] || node.description || node.name || "Application";
        const key = props["application.id"] || props["application.process.binary"] || name;
        if (!groups.has(key)) groups.set(key, { name: name, nodes: [] });
        groups.get(key).nodes.push(node);
    }
    return Array.from(groups.values()).sort((a, b) => a.name.localeCompare(b.name));
}

function routeInfo(route, key) {
    const info = route?.info || [];
    for (let i = 1; i < info.length; i += 2)
        if (info[i] === key) return info[i + 1];
    return "";
}

function bluetoothOutputName(node, device, names = {}) {
    const bluetooth = node["device.api"] === "bluez5" || device["device.api"] === "bluez5"
        || (node["node.name"] || "").startsWith("bluez_output.")
        || (device["device.name"] || "").startsWith("bluez_card.");
    if (!bluetooth) return "";
    const address = device["api.bluez5.address"] || node["api.bluez5.address"]
        || (device["device.name"] || node["node.name"] || "").match(/[0-9a-f]{2}(?:[_:][0-9a-f]{2}){5}/i)?.[0] || "";
    const alias = names[address.replace(/_/g, ":").toUpperCase()];
    if (alias) return alias;
    return device["device.alias"] || device["device.description"] || node["node.description"]
        || device["device.nick"] || node["node.nick"] || "Bluetooth audio";
}

// Availability belongs to a device's routes, not to the playback node itself.
function outputDetails(snapshot, bluetoothNames = {}) {
    const devices = new Map(snapshot.filter(o => o.type === "PipeWire:Interface:Device").map(o => [String(o.id), o]));
    const result = {};
    for (const object of snapshot) {
        const props = object.info?.props || {};
        if (object.type !== "PipeWire:Interface:Node" || props["media.class"] !== "Audio/Sink") continue;
        const device = devices.get(String(props["device.id"]))?.info || {};
        const params = device.params || {};
        const profile = props["card.profile.device"];
        const routes = (params.EnumRoute || []).filter(r => r.direction === "Output"
            && profile !== undefined && (r.devices || []).some(d => String(d) === String(profile)));
        const active = (params.Route || []).find(r => r.direction === "Output"
            && profile !== undefined && String(r.device) === String(profile));
        const route = active || routes.find(r => r.available === "yes")
            || routes.find(r => r.available !== "no") || routes[0];
        // Unknown availability is normal for USB, Bluetooth and virtual outputs.
        // Only hide a device when the driver explicitly reports it unavailable.
        const unavailable = active ? active.available === "no"
            : routes.length > 0 && routes.every(r => r.available === "no");
        const kind = routeInfo(route, "port.type");
        const product = routeInfo(route, "device.product.name");
        const bluetoothName = bluetoothOutputName(props, device.props || {}, bluetoothNames);
        let name = props["node.nick"] || props["node.description"] || "Audio output";
        if (bluetoothName) name = bluetoothName;
        else if (kind === "hdmi") name = product ? "Monitor · " + product : "Monitor audio";
        else if (kind === "headphones") name = "Headphones";
        else if (kind === "speaker") name = "Speakers";
        result[props["node.name"]] = { name: name, unavailable: unavailable };
    }
    return result;
}

function availableOutputs(outputs, details, current) {
    return outputs.filter(node => node === current || !details[node.name]?.unavailable);
}

// Some cards expose speakers and headphones in mutually exclusive profiles.
// Offer their routes even before the corresponding playback node exists.
function inactiveOutputs(snapshot, bluetoothNames = {}) {
    const nodes = snapshot.filter(o => o.type === "PipeWire:Interface:Node" && o.info?.props?.["media.class"] === "Audio/Sink");
    const result = [];
    for (const device of snapshot.filter(o => o.type === "PipeWire:Interface:Device")) {
        const params = device.info?.params || {};
        const props = device.info?.props || {};
        for (const route of params.EnumRoute || []) {
            if (route.direction !== "Output") continue;
            const profileDevice = (route.devices || [])[0];
            if (profileDevice === undefined) continue;
            if (nodes.some(n => String(n.info.props["device.id"]) === String(device.id)
                && (route.devices || []).some(d => String(d) === String(n.info.props["card.profile.device"])))) continue;
            const profiles = (params.EnumProfile || []).filter(p => p.index !== 0 && p.available !== "no"
                && (route.profiles || []).includes(p.index)).sort((a, b) => b.priority - a.priority);
            if (!profiles.length) continue;
            const kind = routeInfo(route, "port.type");
            const product = routeInfo(route, "device.product.name");
            const name = bluetoothOutputName({}, props, bluetoothNames) || (kind === "speaker" ? "Speakers" : kind === "headphones" ? "Headphones"
                : kind === "hdmi" ? (product ? "Monitor · " + product : "Monitor audio")
                : route.description || props["device.description"] || "Audio output");
            result.push({ node: null, name: name, kind: kind, availability: route.available,
                description: (props["device.description"] || "Audio device") + " · " + route.description,
                key: String(device.id) + ":" + route.index,
                deviceId: device.id, deviceName: props["device.name"], profileDevice: profileDevice,
                profileIndex: profiles[0].index, routeIndex: route.index,
                unavailable: route.available === "no" });
        }
    }
    return result;
}

function friendlyName(node, details, outputs) {
    if (!node) return "Audio output";
    function base(n) { return details[n.name]?.name || n.nickname || n.description || "Audio output"; }
    const name = base(node);
    const same = outputs.filter(n => base(n) === name).sort((a, b) => a.name.localeCompare(b.name));
    return same.length > 1 ? name + " (" + (same.indexOf(node) + 1) + ")" : name;
}
