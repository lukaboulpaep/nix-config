import QtQuick

Canvas {
    id: chart
    property var samples: []
    property color lineColor: "#D6B48C"
    property double windowEnd: samples.length ? samples[samples.length - 1].time : Date.now()
    implicitHeight: 82
    antialiasing: true
    onSamplesChanged: if (visible)
        requestPaint()
    onLineColorChanged: if (visible)
        requestPaint()
    onVisibleChanged: if (visible)
        requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const top = 4, bottom = height - 4, plotHeight = bottom - top;
        ctx.lineWidth = 1;
        ctx.strokeStyle = "#303030";
        for (const level of [0, 0.5, 1]) {
            const y = bottom - level * plotHeight;
            ctx.beginPath();
            ctx.moveTo(0, y);
            ctx.lineTo(width, y);
            ctx.stroke();
        }
        const segments = [];
        let segment = [];
        for (const sample of samples) {
            if (sample.time < windowEnd - 120000)
                continue;
            if (sample.value < 0 || !Number.isFinite(sample.value)) {
                if (segment.length)
                    segments.push(segment);
                segment = [];
                continue;
            }
            segment.push({
                x: Math.max(1, Math.min(width - 2, width * (sample.time - windowEnd + 120000) / 120000)),
                y: bottom - Math.max(0, Math.min(100, sample.value)) / 100 * plotHeight
            });
        }
        if (segment.length)
            segments.push(segment);
        for (const points of segments) {
            const fillTop = Math.min(...points.map(p => p.y));
            const gradient = ctx.createLinearGradient(0, Math.min(fillTop, bottom - 1), 0, bottom);
            gradient.addColorStop(0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.24));
            gradient.addColorStop(1, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.015));
            ctx.beginPath();
            ctx.moveTo(points[0].x, bottom);
            for (const p of points)
                ctx.lineTo(p.x, p.y);
            ctx.lineTo(points[points.length - 1].x, bottom);
            ctx.closePath();
            ctx.fillStyle = gradient;
            ctx.fill();
            ctx.beginPath();
            ctx.moveTo(points[0].x, points[0].y);
            for (let i = 1; i < points.length; i++)
                ctx.lineTo(points[i].x, points[i].y);
            ctx.strokeStyle = lineColor;
            ctx.lineWidth = 1.8;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.stroke();
        }
        if (segments.length && samples.length && samples[samples.length - 1].value >= 0) {
            const last = segments[segments.length - 1].slice(-1)[0];
            ctx.beginPath();
            ctx.arc(last.x, last.y, 2.4, 0, 2 * Math.PI);
            ctx.fillStyle = lineColor;
            ctx.fill();
        }
    }
}
