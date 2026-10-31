import QtQuick
import QtQuick.Controls

Button {
    id: button
    property string fontFamily: "Onest"
    property bool accent: false
    implicitHeight: 32
    leftPadding: 11
    rightPadding: 11
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    contentItem: Text {
        text: button.text
        textFormat: Text.PlainText
        color: button.accent ? "#D6B48C" : "#F8F9F9"
        font {
            family: button.fontFamily
            pixelSize: 12
            weight: Font.Medium
        }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 7
        color: button.down ? "#3D352C" : button.hovered ? "#35312C" : button.accent ? "#302B25" : "#2C2C2C"
        border {
            width: 1
            color: button.visualFocus ? "#D6B48C" : "#42403C"
        }
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }
    HoverHandler {
        cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
