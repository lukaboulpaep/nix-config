import QtQuick
import QtQuick.Controls

// Adapted from Pond's CategoryButton and SessionButton. See ../licenses/pond-interface.txt.
Button {
    id: control
    required property url iconSource
    required property string titleFontFamily
    property bool sessionAction: false
    property color hoverColor: "#262626"
    property color controlColor: "#632B0F"
    property int revealDelay: 0
    property bool revealed: false
    highlighted: hovered || visualFocus
    padding: 0
    hoverEnabled: true
    Accessible.name: text
    opacity: revealed ? (enabled ? 1 : 0.4) : 0
    scale: revealed ? 1 : 0.86
    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Component.onCompleted: revealTimer.start()
    Timer {
        id: revealTimer
        interval: control.revealDelay
        onTriggered: control.revealed = true
    }
    background: Rectangle {
        radius: 12
        color: control.highlighted ? control.hoverColor : "#1D1D1D"
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
    }
    contentItem: Item {
        Rectangle {
            visible: control.sessionAction
            anchors.centerIn: parent
            width: 48
            height: 48
            radius: 24
            color: control.highlighted ? control.controlColor : "#2C2C2C"
            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }
        }
        Image {
            x: control.sessionAction ? (parent.width - width) / 2 : 18
            y: control.sessionAction ? (parent.height - height) / 2 : 18
            width: control.sessionAction ? 20 : 28
            height: width
            source: control.iconSource
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
        }
        Text {
            visible: !control.sessionAction
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 18
            }
            text: control.text
            color: "#F8F9F9"
            font {
                family: control.titleFontFamily
                pixelSize: 20
                letterSpacing: -0.4
            }
            elide: Text.ElideRight
        }
    }
    Text {
        visible: control.sessionAction
        x: control.width + 12
        anchors.verticalCenter: parent.verticalCenter
        text: control.text
        color: control.hoverColor
        opacity: control.highlighted ? 0.9 : 0
        font {
            family: control.titleFontFamily
            pixelSize: 20
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }
    }
}
