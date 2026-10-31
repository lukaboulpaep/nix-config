.pragma library

function copy(value) { return JSON.parse(JSON.stringify(value)); }
function dimensions(displays, layout) {
    if (!displays.length) return {x: 0, y: 0, width: 1, height: 1};
    const positions = displays.map(d => layout.positions[d.id] || {x: d.x, y: d.y});
    const x = Math.min(...positions.map(p => p.x));
    const y = Math.min(...positions.map(p => p.y));
    return {x: x, y: y,
        width: Math.max(...displays.map((d, i) => positions[i].x + d.width)) - x,
        height: Math.max(...displays.map((d, i) => positions[i].y + d.height)) - y};
}
function arrange(displays, layout, direction, reverse) {
    const next = copy(layout);
    const order = displays.slice().sort((a, b) => {
        const pa = layout.positions[a.id] || a, pb = layout.positions[b.id] || b;
        return direction === "vertical" ? pa.y - pb.y || pa.x - pb.x : pa.x - pb.x || pa.y - pb.y;
    });
    if (reverse) order.reverse();
    let offset = 0;
    for (const d of order) {
        next.positions[d.id] = direction === "vertical" ? {x: 0, y: offset} : {x: offset, y: 0};
        offset += direction === "vertical" ? d.height : d.width;
    }
    return next;
}
function snap(displays, layout, id, x, y) {
    const next = copy(layout);
    const moving = displays.find(d => d.id === id);
    const others = displays.filter(d => d.id !== id);
    if (!moving || !others.length) return next;
    // Attach to the closest edge, with aligned tops/centres/bottoms as snap points.
    const candidates = [];
    for (const d of others) {
        const p = layout.positions[d.id] || d;
        const ys = [p.y, p.y + d.height - moving.height, Math.round(p.y + (d.height - moving.height) / 2), Math.round(y / 10) * 10];
        const xs = [p.x, p.x + d.width - moving.width, Math.round(p.x + (d.width - moving.width) / 2), Math.round(x / 10) * 10];
        for (const sy of ys) {
            if (sy < p.y + d.height && sy + moving.height > p.y)
                for (const sx of [p.x - moving.width, p.x + d.width]) candidates.push({x: sx, y: sy});
        }
        for (const sx of xs) {
            if (sx < p.x + d.width && sx + moving.width > p.x)
                for (const sy of [p.y - moving.height, p.y + d.height]) candidates.push({x: sx, y: sy});
        }
    }
    const valid = candidates.filter(p => !others.some(d => {
        const q = layout.positions[d.id] || d;
        return p.x < q.x + d.width && q.x < p.x + moving.width && p.y < q.y + d.height && q.y < p.y + moving.height;
    }));
    valid.sort((a, b) => Math.hypot(a.x - x, a.y - y) - Math.hypot(b.x - x, b.y - y));
    if (valid.length) next.positions[id] = valid[0];
    return next;
}
