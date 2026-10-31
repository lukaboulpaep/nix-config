import QtQuick
import QtQuick.Shapes

Item {
    id: icon
    required property string mode
    property color color: "#B8B8B8"
    implicitWidth: 20
    implicitHeight: 20
    Shape {
        anchors.fill: parent
        visible: icon.mode === "power-saver"
        antialiasing: true
        ShapePath {
            strokeColor: icon.color
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 4
            startY: 15
            PathCubic {
                x: 16
                y: 3
                control1X: 0
                control1Y: 6
                control2X: 10
                control2Y: 4
            }
            PathCubic {
                x: 4
                y: 15
                control1X: 18
                control1Y: 13
                control2X: 12
                control2Y: 19
            }
            PathMove {
                x: 3
                y: 18
            }
            PathLine {
                x: 12
                y: 9
            }
        }
    }
    Shape {
        anchors.fill: parent
        visible: icon.mode === "balanced"
        antialiasing: true
        ShapePath {
            strokeColor: icon.color
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: 3
            startY: 5
            PathLine {
                x: 17
                y: 5
            }
            PathMove {
                x: 3
                y: 10
            }
            PathLine {
                x: 17
                y: 10
            }
            PathMove {
                x: 3
                y: 15
            }
            PathLine {
                x: 17
                y: 15
            }
        }
    }
    Repeater {
        model: icon.mode === "balanced" ? [
            {
                x: 7,
                y: 5
            },
            {
                x: 13,
                y: 10
            },
            {
                x: 7,
                y: 15
            }
        ] : []
        Rectangle {
            required property var modelData
            x: modelData.x - 1.5
            y: modelData.y - 2
            width: 3
            height: 4
            radius: 1
            color: icon.color
        }
    }
    Shape {
        anchors.fill: parent
        visible: icon.mode === "performance"
        antialiasing: true
        ShapePath {
            strokeColor: icon.color
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: 11
            startY: 2
            PathLine {
                x: 4
                y: 11
            }
            PathLine {
                x: 10
                y: 11
            }
            PathLine {
                x: 9
                y: 18
            }
            PathLine {
                x: 16
                y: 8
            }
            PathLine {
                x: 10
                y: 8
            }
            PathLine {
                x: 11
                y: 2
            }
        }
    }
}
