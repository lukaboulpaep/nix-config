import QtQuick
import QtQuick.Controls

Item {
    id: header
    required property string title
    required property string subtitle
    required property string icon
    property string fontFamily: "Onest"
    property bool checked: false
    property bool available: true
    signal toggled
    implicitHeight: Math.max(50, labels.implicitHeight)
    Text {
        id: symbol
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        width: 38
        text: header.icon
        color: header.checked ? "#D6B48C" : "#888888"
        font {
            family: "Symbols Nerd Font Mono"
            pixelSize: 24
        }
    }
    Column {
        id: labels
        anchors {
            left: symbol.right
            right: toggle.left
            rightMargin: 12
            verticalCenter: parent.verticalCenter
        }
        spacing: 4
        Text {
            text: header.title
            color: "#F8F9F9"
            font {
                family: header.fontFamily
                pixelSize: 15
                weight: Font.Medium
            }
        }
        Text {
            width: parent.width
            text: header.subtitle
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            color: "#B8B8B8"
            font {
                family: header.fontFamily
                pixelSize: 12
            }
        }
    }
    Switch {
        id: toggle
        objectName: "radio-" + header.title
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: 44
        height: 32
        padding: 0
        checked: header.checked
        enabled: header.available
        Accessible.name: header.title
        onClicked: header.toggled()
        indicator: Rectangle {
            y: 4
            width: 44
            height: 24
            radius: 12
            color: header.checked ? "#D6B48C" : "#454545"
            opacity: toggle.enabled ? 1 : 0.45
            border {
                width: toggle.visualFocus ? 1 : 0
                color: "#FFFFFF"
            }
            Rectangle {
                x: header.checked ? 23 : 3
                y: 3
                width: 18
                height: 18
                radius: 9
                color: header.checked ? "#242424" : "#B8B8B8"
                Behavior on x {
                    NumberAnimation {
                        duration: 120
                    }
                }
            }
        }
        HoverHandler {
            cursorShape: toggle.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        }
    }
}
