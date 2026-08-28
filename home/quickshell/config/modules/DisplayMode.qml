import QtQuick

import "../core" as Core
import "../services" as Services

// Display hot-plug preference

Item {
    id: root

    implicitWidth: 76
    implicitHeight: Core.Theme.moduleHeight

    readonly property var svc: Services.DisplayService

    Rectangle {
        anchors.fill: parent

        radius: height / 2

        color: root.svc.transferOnConnect
            ? Core.Theme.surfaceActive
            : mouse.containsMouse
                ? Core.Theme.surfaceHover
                : "transparent"

        border.width: root.svc.transferOnConnect ? Core.Theme.borderWidth : 0
        border.color: Core.Theme.borderFocus

        Behavior on color {
            ColorAnimation {
                duration: Core.Theme.durFast
                easing.type: Easing.OutQuint
            }
        }
    }

    Row {
        anchors.centerIn: parent

        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: Core.Icons.computer

            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.iconSize

            color: root.svc.transferOnConnect ? Core.Theme.accent : Core.Theme.foregroundMuted

            Behavior on color {
                ColorAnimation {
                    duration: Core.Theme.durFast
                    easing.type: Easing.OutQuint
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: root.svc.modeLabel

            font.family: Core.Theme.fontFamily
            font.pixelSize: Core.Theme.fontSizeSmall
            font.weight: root.svc.transferOnConnect ? Font.DemiBold : Font.Medium

            color: root.svc.transferOnConnect ? Core.Theme.accent : Core.Theme.foregroundMuted

            Behavior on color {
                ColorAnimation {
                    duration: Core.Theme.durFast
                    easing.type: Easing.OutQuint
                }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: root.svc.toggleTransferOnConnect()
    }

    scale: mouse.pressed ? 0.96 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Core.Theme.durFast
            easing.type: Easing.OutQuint
        }
    }
}
