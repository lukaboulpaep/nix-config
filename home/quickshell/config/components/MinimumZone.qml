import QtQuick

import "../core" as Core

// MinimumZone
// A compact warning hatch for the part of a level track that hardware cannot
// enter. Its right edge is the actual selectable floor.

Item {
    id: root

    property color tint: Core.Theme.warning

    // Canvas clipping follows the actual half-round cap. This lets the hatch
    // reach the very left end without leaking through the curved border.
    Canvas {
        id: canvas

        anchors.fill: parent

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            target: root

            function onTintChanged() {
                canvas.requestPaint();
            }
        }

        onPaint: {
            const ctx = getContext("2d");
            const w = width;
            const h = height;
            const radius = Math.min(w, h / 2);

            ctx.clearRect(0, 0, w, h);
            ctx.save();

            ctx.beginPath();
            ctx.moveTo(radius, 0);
            ctx.lineTo(w, 0);
            ctx.lineTo(w, h);
            ctx.lineTo(radius, h);
            ctx.arc(radius, radius, radius, Math.PI / 2, Math.PI * 3 / 2, false);
            ctx.closePath();
            ctx.clip();

            ctx.globalAlpha = 0.16;
            ctx.fillStyle = root.tint;
            ctx.fillRect(0, 0, w, h);

            ctx.globalAlpha = 0.72;
            ctx.strokeStyle = root.tint;
            ctx.lineWidth = 2;

            for (let x = -h; x < w + h; x += 7) {
                ctx.beginPath();
                ctx.moveTo(x, h);
                ctx.lineTo(x + h, 0);
                ctx.stroke();
            }

            ctx.globalAlpha = 0.95;
            ctx.fillStyle = root.tint;
            ctx.fillRect(Math.max(0, w - 1), 0, 1, h);
            ctx.restore();
        }
    }
}
