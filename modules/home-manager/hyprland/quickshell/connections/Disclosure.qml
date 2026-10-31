import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

Button {
    id: button
    property string fontFamily: "Onest"
    checkable: true
    implicitHeight: 32
    leftPadding: 3
    rightPadding: 9
    topPadding: 0
    bottomPadding: 0
    hoverEnabled: true
    Accessible.description: checked ? "Expanded" : "Collapsed"
    background: Rectangle {
        radius: 6
        color: button.down ? "#39342F" : button.hovered || button.visualFocus ? "#302C28" : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }
    contentItem: Item {
        Text {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            width: parent.width - 26
            elide: Text.ElideRight
            text: button.text
            color: "#B8B8B8"
            textFormat: Text.PlainText
            font {
                family: button.fontFamily
                pixelSize: 13
            }
        }
        Shape {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            width: 16
            height: 16
            antialiasing: true
            rotation: button.checked ? 90 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: 120
                }
            }
            ShapePath {
                strokeColor: "#D6B48C"
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                startX: 6
                startY: 3.5
                PathLine {
                    x: 10.5
                    y: 8
                }
                PathLine {
                    x: 6
                    y: 12.5
                }
            }
        }
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
}
