pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "DisplayModel.js" as Model

Rectangle {
    id: diagram
    required property var displays
    required property var layout
    required property string fontFamily
    property string selected: ""
    property bool previews: true
    property bool active: false
    property bool editable: true
    signal moved(string id, real layoutX, real layoutY)
    signal selectedDisplay(string id)
    readonly property bool mirror: layout.mode === "mirror"
    readonly property var bounds: Model.dimensions(displays, layout)
    readonly property real factor: Math.min((width - 40) / Math.max(1, bounds.width), (height - 50) / Math.max(1, bounds.height))
    readonly property real originX: (width - bounds.width * factor) / 2
    readonly property real originY: (height - bounds.height * factor) / 2
    height: 210
    radius: 11
    color: "#171717"
    border {
        width: 1
        color: "#343434"
    }
    clip: true
    Repeater {
        model: diagram.displays
        delegate: Rectangle {
            id: tile
            required property var modelData
            required property int index
            readonly property var position: diagram.layout.positions[modelData.id] || modelData
            readonly property real baseX: diagram.mirror ? 20 + index * (diagram.width - 40) / Math.max(1, diagram.displays.length) : diagram.originX + (position.x - diagram.bounds.x) * diagram.factor
            readonly property real baseY: diagram.mirror ? (diagram.height - height) / 2 : diagram.originY + (position.y - diagram.bounds.y) * diagram.factor
            readonly property var sourceDisplay: diagram.mirror ? diagram.displays.find(d => d.id === diagram.layout.primary) : modelData
            readonly property var captureScreen: Quickshell.screens.find(s => s.name === (sourceDisplay?.name || "")) ?? null
            property real offsetX: 0
            property real offsetY: 0
            x: baseX + offsetX
            y: baseY + offsetY
            width: diagram.mirror ? (diagram.width - 40) / Math.max(1, diagram.displays.length) - 7 : modelData.width * diagram.factor - 3
            height: diagram.mirror ? Math.min(120, width * modelData.height / modelData.width) : modelData.height * diagram.factor - 3
            radius: 5
            color: "#302C28"
            border {
                width: 2
                color: diagram.selected === modelData.id ? "#D6B48C" : "#66605A"
            }
            z: dragArea.pressed ? 2 : 1
            Item {
                anchors {
                    fill: parent
                    margins: 3
                }
                clip: true
                ScreencopyView {
                    id: preview
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height * (sourceSize.width / Math.max(1, sourceSize.height)))
                    height: Math.min(parent.height, parent.width * (sourceSize.height / Math.max(1, sourceSize.width)))
                    captureSource: diagram.active && diagram.previews ? tile.captureScreen : null
                    live: diagram.active && diagram.previews
                    paintCursor: false
                    constraintSize: Qt.size(400, 240)
                }
                Rectangle {
                    anchors.fill: parent
                    color: "#20000000"
                    visible: preview.hasContent
                }
                Text {
                    anchors.centerIn: parent
                    visible: !preview.hasContent
                    text: tile.modelData.internal ? "󰌢" : "󰍹"
                    color: "#696158"
                    font.pixelSize: 32
                }
            }
            Rectangle {
                x: 6
                y: 6
                width: numberLabel.implicitWidth + 12
                height: 21
                radius: 5
                color: "#E61D1D1D"
                Text {
                    id: numberLabel
                    anchors.centerIn: parent
                    text: (tile.index + 1) + (diagram.layout.primary === tile.modelData.id ? " · Main" : "")
                    color: "#F8F9F9"
                    font {
                        family: diagram.fontFamily
                        pixelSize: 10
                        weight: Font.Medium
                    }
                }
            }
            MouseArea {
                id: dragArea
                anchors.fill: parent
                cursorShape: diagram.editable && !diagram.mirror ? Qt.OpenHandCursor : Qt.PointingHandCursor
                property point start
                property bool dragging: false
                onPressed: mouse => {
                    start = mapToItem(diagram, mouse.x, mouse.y);
                    dragging = false;
                    diagram.selectedDisplay(tile.modelData.id);
                }
                onPositionChanged: mouse => {
                    if (!pressed || !diagram.editable || diagram.mirror)
                        return;
                    const point = mapToItem(diagram, mouse.x, mouse.y);
                    tile.offsetX = point.x - start.x;
                    tile.offsetY = point.y - start.y;
                    if (Math.hypot(tile.offsetX, tile.offsetY) > 4)
                        dragging = true;
                }
                onReleased: {
                    if (dragging)
                        diagram.moved(tile.modelData.id, tile.position.x + tile.offsetX / diagram.factor, tile.position.y + tile.offsetY / diagram.factor);
                    tile.offsetX = 0;
                    tile.offsetY = 0;
                    dragging = false;
                }
                onCanceled: {
                    tile.offsetX = 0;
                    tile.offsetY = 0;
                    dragging = false;
                }
            }
        }
    }
    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 8
        }
        text: diagram.mirror ? "Same content on every display" : "Drag displays to match your desk"
        color: "#B8B8B8"
        font {
            family: diagram.fontFamily
            pixelSize: 11
        }
    }
}
