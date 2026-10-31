pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower
import "BatteryModel.js" as Model

import ".." as BarComponents

PanelWindow {
    id: menu
    required property var theme
    property bool opened: false
    property int switchDirection: 0
    property alias switching: scene.switching
    property alias held: scene.held
    property var handoffFrom: null
    readonly property Item card: panel
    property real anchorCenter: width - theme.barMargin
    property bool detailsExpanded: false
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery.ready && battery.isPresent && battery.isLaptopBattery
    readonly property var batteries: UPower.devices.values.filter(d => d.ready && d.isPresent && d.isLaptopBattery)
    readonly property int percentage: hasBattery ? Math.round(battery.percentage * 100) : -1
    readonly property bool charging: hasBattery && battery.state === UPowerDeviceState.Charging
    readonly property bool discharging: hasBattery && battery.state === UPowerDeviceState.Discharging
    readonly property bool plugged: !UPower.onBattery
    readonly property real health: Model.health(batteries)
    readonly property string status: !hasBattery ? "No battery detected" : charging ? "Charging" : battery.state === UPowerDeviceState.FullyCharged ? "Fully charged" : discharging ? "On battery" : plugged ? "Plugged in · not charging" : "On battery"
    readonly property string estimate: {
        if (!hasBattery)
            return "Power modes are still available below.";
        const time = Model.duration(charging ? battery.timeToFull : discharging ? battery.timeToEmpty : 0);
        if (charging)
            return time ? "About " + time + " until full" : "Estimating time until full…";
        if (discharging)
            return time ? "About " + time + " remaining" : "Estimating time remaining…";
        return plugged ? "Running on external power" : "Time estimate unavailable";
    }
    property var cycles: ({})
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
    WlrLayershell.namespace: "quickshell-battery"
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
        cycleReader.running = true;
    }
    onDetailsExpandedChanged: if (!detailsExpanded)
        Qt.callLater(() => scroll.contentItem.returnToBounds())
    PowerService {
        id: power
        active: menu.opened
    }
    Process {
        id: cycleReader
        command: ["bash", Quickshell.shellPath("battery/battery-cycles.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = {};
                for (const line of text.trim().split("\n")) {
                    const fields = line.split("\t");
                    if (fields.length === 2 && /^\d+$/.test(fields[1]))
                        result[fields[0]] = Number(fields[1]);
                }
                menu.cycles = result;
            }
        }
    }
    component Label: Text {
        textFormat: Text.PlainText
        color: "#B8B8B8"
        font {
            family: menu.theme.fontFamily
            pixelSize: 12
        }
        wrapMode: Text.WordWrap
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
            objectName: "batteryPanel"
            anchors {
                top: parent.top
                topMargin: menu.theme.barMargin + menu.theme.barHeight + 8
            }
            x: Math.max(menu.theme.barMargin, Math.min(menu.anchorCenter - width / 2, (menu.screen?.width ?? menu.width) - width - menu.theme.barMargin))
            width: Math.min(400, (menu.screen?.width ?? menu.width) - 2 * menu.theme.barMargin)
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
                text: "Battery"
                color: "#F8F9F9"
                font {
                    family: "serif"
                    pixelSize: 23
                }
            }
            ScrollView {
                id: scroll
                objectName: "batteryScroll"
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
                    Column {
                        width: parent.width
                        spacing: 9
                        BatteryGauge {
                            anchors.horizontalCenter: parent.horizontalCenter
                            percentage: menu.percentage
                            charging: menu.charging
                            plugged: menu.plugged
                            animate: menu.opened
                            fontFamily: menu.theme.fontFamily
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: menu.status
                            color: "#F8F9F9"
                            font {
                                pixelSize: 15
                                weight: Font.Medium
                            }
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: menu.estimate
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: 9
                        Label {
                            text: "Power mode"
                            color: "#F8F9F9"
                            font {
                                pixelSize: 13
                                weight: Font.Medium
                            }
                        }
                        Repeater {
                            model: ["power-saver", "balanced", "performance"].filter(id => power.profiles.some(p => p.id === id))
                            Button {
                                id: mode
                                required property string modelData
                                readonly property bool selected: power.profile === modelData
                                width: body.width
                                height: 57
                                leftPadding: 13
                                rightPadding: 14
                                enabled: power.available && !power.requested
                                hoverEnabled: true
                                Accessible.name: Model.profileName(modelData)
                                Accessible.description: selected ? "Selected power mode" : "Switch power mode"
                                onClicked: power.select(modelData)
                                background: Rectangle {
                                    radius: 10
                                    color: mode.down ? "#37312A" : mode.selected ? "#302B25" : mode.hovered ? "#2D2D2D" : "#242424"
                                    border {
                                        width: 1
                                        color: mode.visualFocus ? "#F8F9F9" : mode.selected ? "#76654F" : "#343434"
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                }
                                contentItem: Item {
                                    PowerModeIcon {
                                        anchors {
                                            left: parent.left
                                            verticalCenter: parent.verticalCenter
                                        }
                                        mode: parent.parent.modelData
                                        color: parent.parent.selected ? "#D6B48C" : "#B8B8B8"
                                    }
                                    Column {
                                        x: 32
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 60
                                        spacing: 3
                                        Label {
                                            text: Model.profileName(mode.modelData)
                                            color: mode.selected ? "#D6B48C" : "#F8F9F9"
                                            font {
                                                pixelSize: 13
                                                weight: Font.Medium
                                            }
                                        }
                                        Label {
                                            text: ({
                                                    "power-saver": "Longer battery life",
                                                    "balanced": "Everyday use",
                                                    "performance": "More speed, more power"
                                                })[mode.modelData]
                                        }
                                    }
                                    Rectangle {
                                        anchors {
                                            right: parent.right
                                            verticalCenter: parent.verticalCenter
                                        }
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: "transparent"
                                        border {
                                            width: 1
                                            color: mode.selected ? "#D6B48C" : "#777777"
                                        }
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: "#D6B48C"
                                            visible: mode.selected
                                        }
                                    }
                                }
                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                        Label {
                            width: parent.width
                            visible: !power.available || power.error.length > 0 || power.requested.length > 0
                            text: power.error || (power.requested ? "Switching power mode…" : power.busy ? "Checking power modes…" : "Power modes aren’t available. The power service may need to be enabled.")
                            color: power.error ? "#EBA095" : "#B8B8B8"
                        }
                        Label {
                            width: parent.width
                            visible: power.profiles.some(p => p.id === power.profile && p.degraded.length > 0)
                            text: "Performance is temporarily limited by the system."
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: healthContent.implicitHeight + 28
                        visible: menu.hasBattery
                        radius: 12
                        color: "#242424"
                        border {
                            width: 1
                            color: "#343434"
                        }
                        Column {
                            id: healthContent
                            x: 14
                            y: 14
                            width: parent.width - 28
                            spacing: 8
                            Row {
                                width: parent.width
                                Label {
                                    width: parent.width - 75
                                    text: "Battery health"
                                    color: "#F8F9F9"
                                    font {
                                        pixelSize: 13
                                        weight: Font.Medium
                                    }
                                }
                                Label {
                                    width: 75
                                    horizontalAlignment: Text.AlignRight
                                    text: menu.health >= 0 ? Math.round(menu.health) + "%" : "Unknown"
                                    color: menu.health >= 80 ? "#A9C7BC" : "#D6B48C"
                                    font {
                                        pixelSize: 14
                                        weight: Font.Medium
                                    }
                                }
                            }
                            Rectangle {
                                visible: menu.health >= 0
                                width: parent.width
                                height: 4
                                radius: 2
                                color: "#383838"
                                Rectangle {
                                    width: parent.width * Math.max(0, menu.health) / 100
                                    height: 4
                                    radius: 2
                                    color: menu.health >= 80 ? "#A9C7BC" : "#D6B48C"
                                }
                            }
                            Label {
                                width: parent.width
                                text: menu.health >= 0 ? "How much charge your battery can hold compared with when it was new." : "This battery doesn’t report its original capacity."
                            }
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: 10
                        visible: menu.hasBattery
                        Button {
                            id: detailsButton
                            width: parent.width
                            height: 32
                            leftPadding: 3
                            rightPadding: 9
                            topPadding: 0
                            bottomPadding: 0
                            text: "Battery details"
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
                        Column {
                            width: parent.width
                            spacing: 12
                            visible: menu.detailsExpanded
                            Label {
                                width: parent.width
                                visible: menu.charging || menu.discharging
                                text: (menu.charging ? "Charging at  " : "Power draw  ") + Math.abs(menu.battery.changeRate).toFixed(1) + " W"
                                color: "#D6B48C"
                            }
                            Repeater {
                                model: menu.batteries
                                Column {
                                    required property var modelData
                                    required property int index
                                    readonly property string batteryId: modelData.nativePath.split("/").pop()
                                    width: body.width
                                    spacing: 6
                                    Label {
                                        visible: menu.batteries.length > 1
                                        text: "Battery " + (parent.index + 1)
                                        color: "#F8F9F9"
                                    }
                                    Label {
                                        width: parent.width
                                        text: "Full charge capacity  " + (parent.modelData.energyCapacity > 0 ? parent.modelData.energyCapacity.toFixed(1) + " Wh" : "Unavailable")
                                    }
                                    Label {
                                        width: parent.width
                                        visible: menu.cycles[parent.batteryId] !== undefined
                                        text: "Charge cycles  " + (menu.cycles[parent.batteryId] ?? "")
                                    }
                                }
                            }
                            Label {
                                width: parent.width
                                text: "A cycle is one full battery’s worth of use, even across several charges."
                            }
                        }
                    }
                }
            }
        }
    }
}
