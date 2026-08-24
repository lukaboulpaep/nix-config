import QtQuick
import QtQuick.Layouts

import Quickshell

import "../core" as Core
import "../services" as Services

// Brightness (bar module)

Item {
    id: root

    implicitWidth: 58
    implicitHeight: Core.Theme.moduleHeight

    readonly property int level: Services.BrightnessService.level

    readonly property bool menuOpen: Core.PopupManager.isOpen("brightness")

    Rectangle {
        anchors.fill: parent

        radius: height / 2

        color: root.menuOpen ? Core.Theme.surfaceActive : (mouse.containsMouse ? Core.Theme.hover : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: 100
                easing.type: Easing.OutQuint
            }
        }
    }

    RowLayout {
        anchors.centerIn: parent

        spacing: 5

        Text {
            // Ramps with the level instead of showing the same sun at 5% and at 100%.
            text: Core.Icons.forBrightness(Services.BrightnessService.fraction)

            font.family: Core.Theme.fontFamily

            font.pixelSize: Core.Theme.iconSize

            color: root.menuOpen ? Core.Theme.accent : Core.Theme.foreground

            Behavior on color {
                ColorAnimation {
                    duration: 120
                    easing.type: Easing.OutQuint
                }
            }
        }

        Text {
            text: root.level + "%"

            font.family: Core.Theme.fontFamily

            font.pixelSize: Core.Theme.fontSize

            font.weight: Font.Medium

            color: Core.Theme.foreground

            renderType: Text.QtRendering
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent

        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton

        onWheel: function (event) {
            if (event.angleDelta.y === 0)
                return;
            Services.BrightnessService.step(event.angleDelta.y > 0);
        }

        onClicked: {
            const p = root.mapToItem(null, 0, root.height);

            Core.PopupManager.toggle("brightness", p.x + root.width / 2, p.y + Core.Theme.barMarginTop);
        }
    }
}
