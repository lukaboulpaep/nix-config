pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "Stats.js" as Stats

import ".." as BarComponents

PanelWindow {
    id: menu
    required property var theme
    required property var stats
    property bool opened: false
    property int switchDirection: 0
    property alias switching: scene.switching
    property alias held: scene.held
    property var handoffFrom: null
    readonly property Item card: panel
    property real anchorCenter: width - theme.barMargin
    property bool detailsExpanded: false
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
    WlrLayershell.namespace: "quickshell-system"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    visible: opened || scene.visible
    function openOn(targetScreen) {
        screen = targetScreen;
        opened = true;
    }
    onOpenedChanged: if (opened) {
        scene.forceActiveFocus();
        scroll.contentItem.contentY = 0;
    }
    onDetailsExpandedChanged: if (!detailsExpanded)
        Qt.callLater(() => scroll.contentItem.returnToBounds())

    component Label: Text {
        textFormat: Text.PlainText
        color: "#B8B8B8"
        font {
            family: menu.theme.fontFamily
            pixelSize: 12
        }
        wrapMode: Text.WordWrap
    }
    component ChartCard: Rectangle {
        id: card
        required property string title
        required property string detail
        required property int usage
        required property var samples
        property color accent: "#D6B48C"
        implicitHeight: 162
        color: "#242424"
        radius: 12
        Accessible.role: Accessible.StaticText
        Accessible.name: title + ": " + (usage < 0 ? "unavailable" : usage + " percent") + ". " + detail
        Label {
            x: 14
            y: 12
            text: card.title
            color: "#F8F9F9"
            font {
                pixelSize: 13
                weight: Font.Medium
            }
        }
        Label {
            anchors {
                right: parent.right
                rightMargin: 14
                top: parent.top
                topMargin: 8
            }
            text: card.usage < 0 ? "—" : card.usage + "%"
            color: card.accent
            font.pixelSize: 25
        }
        Label {
            x: 14
            y: 34
            width: parent.width - 100
            text: card.detail
            font.pixelSize: 11
        }
        Label {
            anchors {
                right: parent.right
                rightMargin: 14
            }
            y: 49
            text: "0–100%"
            color: "#888888"
            font.pixelSize: 9
        }
        HistoryChart {
            x: 14
            y: 62
            width: parent.width - 28
            height: 76
            samples: card.samples
            lineColor: card.accent
            visible: menu.opened
        }
        Label {
            x: 14
            y: 142
            text: "2 min ago"
            color: "#888888"
            font.pixelSize: 10
        }
        Label {
            anchors {
                right: parent.right
                rightMargin: 14
            }
            y: 142
            text: "Now"
            color: "#888888"
            font.pixelSize: 10
        }
        Label {
            anchors.centerIn: parent
            visible: card.samples.filter(p => p.value >= 0).length < 2
            text: "Collecting history…"
            color: "#888888"
            font.pixelSize: 11
        }
    }
    component StatTile: Rectangle {
        id: tile
        required property string label
        required property string value
        property string detail: ""
        implicitHeight: 76
        radius: 10
        color: "#242424"
        Label {
            x: 12
            y: 10
            width: parent.width - 24
            text: tile.label
            font.pixelSize: 11
        }
        Label {
            x: 12
            y: 29
            width: parent.width - 24
            text: tile.value
            color: "#F8F9F9"
            font.pixelSize: 19
        }
        Label {
            x: 12
            y: 55
            width: parent.width - 24
            text: tile.detail
            font.pixelSize: 10
            color: "#888888"
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
            objectName: "systemPanel"
            anchors {
                top: parent.top
                topMargin: menu.theme.barMargin + menu.theme.barHeight + 8
            }
            x: Math.max(menu.theme.barMargin, Math.min(menu.anchorCenter - width / 2, (menu.screen?.width ?? menu.width) - width - menu.theme.barMargin))
            width: Math.min(440, (menu.screen?.width ?? menu.width) - 2 * menu.theme.barMargin)
            height: Math.min(body.implicitHeight + 92, menu.height - y - 16)
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
                text: "System"
                color: "#F8F9F9"
                font {
                    family: "serif"
                    pixelSize: 23
                }
            }
            ScrollView {
                id: scroll
                objectName: "systemScroll"
                anchors {
                    fill: parent
                    leftMargin: 22
                    rightMargin: 22
                    topMargin: 68
                    bottomMargin: 24
                }
                contentWidth: availableWidth
                contentHeight: body.implicitHeight
                clip: true
                Component.onCompleted: contentItem.boundsBehavior = Flickable.StopAtBounds
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
                Column {
                    id: body
                    width: scroll.availableWidth
                    spacing: 12
                    ChartCard {
                        width: parent.width
                        title: "CPU"
                        usage: menu.stats.cpu
                        samples: menu.stats.cpuHistory
                        detail: "Processor activity · " + menu.stats.cores.length + " threads"
                    }
                    ChartCard {
                        width: parent.width
                        title: "RAM"
                        usage: menu.stats.memory
                        samples: menu.stats.memoryHistory
                        accent: "#A9C7BC"
                        detail: menu.stats.memoryTotal ? Stats.bytes(menu.stats.memoryUsed) + " of " + Stats.bytes(menu.stats.memoryTotal) + " in use" : "Memory usage"
                    }
                    Grid {
                        width: parent.width
                        columns: 2
                        spacing: 10
                        StatTile {
                            width: (body.width - 10) / 2
                            label: "↓ Download"
                            value: menu.stats.download < 0 ? "—" : Stats.bytes(menu.stats.download) + "/s"
                            detail: menu.stats.route4 || menu.stats.route6 ? "Current network traffic" : "No active connection"
                        }
                        StatTile {
                            width: (body.width - 10) / 2
                            label: "↑ Upload"
                            value: menu.stats.upload < 0 ? "—" : Stats.bytes(menu.stats.upload) + "/s"
                            detail: "Current network traffic"
                        }
                        StatTile {
                            width: (body.width - 10) / 2
                            label: "CPU temperature"
                            value: menu.stats.temperature < 0 ? "—" : Math.round(menu.stats.temperature) + " °C"
                            detail: menu.stats.temperature < 0 ? "No sensor available" : "Processor sensor"
                        }
                        StatTile {
                            width: (body.width - 10) / 2
                            label: "Uptime"
                            value: Stats.uptime(menu.stats.uptimeSeconds)
                            detail: "Since the last restart"
                        }
                    }
                    Repeater {
                        model: menu.stats.disks.length
                        Rectangle {
                            id: disk
                            required property int index
                            readonly property var modelData: menu.stats.disks[index] ?? ({
                                    name: "",
                                    total: 1,
                                    used: 0,
                                    available: 0
                                })
                            width: body.width
                            height: 82
                            radius: 10
                            color: "#242424"
                            Label {
                                x: 12
                                y: 10
                                text: disk.modelData.name
                                color: "#F8F9F9"
                            }
                            Label {
                                anchors {
                                    right: parent.right
                                    rightMargin: 12
                                }
                                y: 10
                                text: Math.round(100 * disk.modelData.used / disk.modelData.total) + "% used"
                                color: "#D6B48C"
                            }
                            Rectangle {
                                x: 12
                                y: 36
                                width: parent.width - 24
                                height: 5
                                radius: 3
                                color: "#383838"
                                Rectangle {
                                    width: parent.width * Math.min(1, disk.modelData.used / disk.modelData.total)
                                    height: 5
                                    radius: 3
                                    color: "#D6B48C"
                                }
                            }
                            Label {
                                x: 12
                                y: 51
                                text: Stats.bytes(disk.modelData.available) + " free of " + Stats.bytes(disk.modelData.total)
                                font.pixelSize: 11
                            }
                        }
                    }
                    Label {
                        width: parent.width
                        visible: menu.stats.storageFailed
                        text: "Storage information is unavailable."
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#383838"
                    }
                    Button {
                        id: detailsButton
                        width: parent.width
                        height: 32
                        leftPadding: 3
                        rightPadding: 9
                        topPadding: 0
                        bottomPadding: 0
                        text: "Hardware details"
                        checkable: true
                        checked: menu.detailsExpanded
                        onClicked: menu.detailsExpanded = checked
                        Accessible.description: checked ? "Expanded" : "Collapsed"
                        background: Rectangle {
                            radius: 6
                            color: detailsButton.down ? "#39342F" : detailsButton.hovered || detailsButton.visualFocus ? "#302C28" : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                        }
                        contentItem: Item {
                            Label {
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                text: detailsButton.text
                                font.pixelSize: 13
                            }
                            Shape {
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                width: 16
                                height: 16
                                antialiasing: true
                                rotation: menu.detailsExpanded ? 90 : 0
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
                    HardwareDetails {
                        width: parent.width
                        visible: menu.detailsExpanded
                        stats: menu.stats
                        theme: menu.theme
                    }
                }
            }
        }
    }
}
