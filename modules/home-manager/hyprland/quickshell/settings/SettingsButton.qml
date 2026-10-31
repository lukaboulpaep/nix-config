import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string fontFamily: "Onest"
    property color fillColor: "#2C2C2C"
    property color textColor: "#F8F9F9"
    implicitHeight: 38
    implicitWidth: Math.max(90, label.implicitWidth + 28)
    padding: 12
    hoverEnabled: true
    Accessible.name: text
    background: Rectangle {
        radius: 10
        color: control.down ? Qt.lighter(control.fillColor, 1.3) : control.hovered || control.visualFocus ? Qt.lighter(control.fillColor, 1.15) : control.fillColor
        opacity: control.enabled ? 1 : 0.45
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
    }
    contentItem: Text {
        id: label
        text: control.text
        color: control.textColor
        opacity: control.enabled ? 1 : 0.45
        font {
            family: control.fontFamily
            pixelSize: 13
        }
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
