pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

import ".." as BarComponents

PanelWindow {
    id: menu
    required property var theme
    required property var service
    property bool opened: false
    property int switchDirection: 0
    property alias switching: scene.switching
    property alias held: scene.held
    property var handoffFrom: null
    readonly property Item card: panel
    property real anchorCenter: width - theme.barMargin
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    mask: BarComponents.BarMenuMask {
        menuWindow: menu
        barBottom: menu.theme.barMargin + menu.theme.barHeight
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-connections"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    visible: opened || scene.visible
    function openOn(targetScreen) {
        screen = targetScreen;
        opened = true;
    }
    function settleScroll() {
        Qt.callLater(() => scroll.contentItem.returnToBounds());
    }
    onOpenedChanged: if (opened) {
        scene.forceActiveFocus();
        scroll.contentItem.contentY = 0;
    }
    Connections {
        target: menu.service
        function onPasswordNetworkChanged() {
            if (menu.service.passwordNetwork)
                scroll.contentItem.contentY = 0;
        }
    }
    BarComponents.BarMenuScene {
        id: scene
        opened: menu.opened
        Keys.onEscapePressed: menu.opened = false
        MouseArea {
            anchors.fill: parent
            onClicked: menu.opened = false
        }
        RectangularShadow {
            anchors.fill: panel
            radius: panel.radius
            blur: 20
            offset.y: 4
            color: "#50000000"
        }
        BarComponents.BarMenuCard {
            id: panel
            menuWindow: menu
            objectName: "connectionsPanel"
            anchors {
                top: parent.top
                topMargin: menu.theme.barMargin + menu.theme.barHeight + 8
            }
            x: Math.max(menu.theme.barMargin, Math.min(menu.anchorCenter - width / 2, (menu.screen?.width ?? menu.width) - width - menu.theme.barMargin))
            width: Math.min(420, (menu.screen?.width ?? menu.width) - 2 * menu.theme.barMargin)
            height: Math.min(body.implicitHeight + 86, menu.height - y - 16)
            color: "#1D1D1D"
            radius: 16
            border {
                width: 1
                color: "#383838"
            }
            MouseArea {
                anchors.fill: parent
            }
            Text {
                x: 22
                y: 18
                text: "Connections"
                color: "#F8F9F9"
                font {
                    family: "serif"
                    pixelSize: 23
                }
            }
            ScrollView {
                id: scroll
                objectName: "connectionsScroll"
                anchors {
                    fill: parent
                    leftMargin: 22
                    rightMargin: 22
                    topMargin: 64
                    bottomMargin: 22
                }
                contentWidth: availableWidth
                contentHeight: body.implicitHeight
                clip: true
                Component.onCompleted: contentItem.boundsBehavior = Flickable.StopAtBounds
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                Column {
                    id: body
                    width: scroll.availableWidth
                    spacing: 20
                    WifiPanel {
                        width: parent.width
                        service: menu.service
                        fontFamily: menu.theme.fontFamily
                        onResized: menu.settleScroll()
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#383838"
                    }
                    BluetoothPanel {
                        width: parent.width
                        service: menu.service
                        fontFamily: menu.theme.fontFamily
                        active: menu.opened
                        onResized: menu.settleScroll()
                    }
                }
            }
        }
    }
}
