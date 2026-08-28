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

    property var popupScreen: null

    readonly property string monitorName: root.popupScreen ? root.popupScreen.name : ""

    readonly property int level: Services.BrightnessService.levelFor(root.monitorName)

    readonly property real fraction: root.level < 0 ? 0 : root.level / 100

    readonly property bool menuOpen: Core.PopupManager.isOpen("brightness", root.popupScreen)

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
            text: Core.Icons.forBrightness(root.fraction)

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
            text: root.level < 0 ? "--" : root.level + "%"

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
            Services.BrightnessService.step(event.angleDelta.y > 0, root.monitorName);
        }

        onClicked: {
            const p = root.mapToItem(null, 0, root.height);

            Core.PopupManager.toggle("brightness", p.x + root.width / 2, p.y + Core.Theme.barMarginTop, root.popupScreen);
        }
    }
}
