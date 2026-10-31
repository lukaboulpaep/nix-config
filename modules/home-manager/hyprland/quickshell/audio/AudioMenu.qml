pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "../settings" as Settings
import "AudioModel.js" as AudioModel

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
    property bool advanced: false
    readonly property var outputs: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)
    readonly property var streams: Pipewire.nodes.values.filter(node => node.type === PwNodeType.AudioOutStream)
    readonly property var applications: AudioModel.applications(streams)
    readonly property var outputChoices: outputs.map(node => ({
                node: node,
                name: friendlyName(node),
                description: deviceName(node),
                key: node.name,
                unavailable: node !== Pipewire.defaultAudioSink && (devices.details[node.name]?.unavailable ?? false)
            })).concat(devices.inactiveOutputs.filter(choice => !outputs.some(node => String(node.properties["device.id"]) === String(choice.deviceId) && String(node.properties["card.profile.device"]) === String(choice.profileDevice))))
    readonly property var visibleOutputs: advanced ? outputChoices : outputChoices.filter(choice => !choice.unavailable && (choice.node || ["speaker", "headphones"].includes(choice.kind) || choice.availability === "yes"))
    property var pendingOutput: null
    property var pendingRoute: null
    property string outputMessage: ""

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    mask: BarComponents.BarMenuMask {
        menuWindow: menu
        barBottom: menu.theme.barMargin + menu.theme.barHeight
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-audio"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    visible: opened || scene.visible

    function openOn(targetScreen) {
        screen = targetScreen;
        opened = true;
    }
    function deviceName(node) {
        return node?.description || node?.nickname || node?.name || "Audio output";
    }
    function friendlyName(node) {
        return AudioModel.friendlyName(node, devices.details, outputs);
    }
    function selectOutput(node) {
        outputMessage = "";
        if (node === Pipewire.defaultAudioSink)
            return;
        pendingOutput = node;
        Pipewire.preferredDefaultAudioSink = node;
        outputTimeout.restart();
    }
    function selectChoice(choice) {
        if (devices.activating)
            return;
        if (choice.node) {
            pendingRoute = null;
            selectOutput(choice.node);
            return;
        }
        outputMessage = "";
        pendingRoute = choice;
        devices.activate(choice);
        routeTimeout.restart();
    }
    function finishRouteSelection() {
        if (!pendingRoute || devices.activating)
            return;
        const node = outputs.find(n => n.ready && String(n.properties["device.id"]) === String(pendingRoute.deviceId) && String(n.properties["card.profile.device"]) === String(pendingRoute.profileDevice));
        if (!node)
            return;
        pendingRoute = null;
        routeTimeout.stop();
        selectOutput(node);
    }
    Timer {
        interval: 100
        running: menu.pendingRoute !== null
        repeat: true
        onTriggered: menu.finishRouteSelection()
    }
    Timer {
        id: routeTimeout
        interval: 5000
        onTriggered: {
            menu.pendingRoute = null;
            menu.outputMessage = "This output could not be enabled. Please try again.";
        }
    }
    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            if (menu.pendingOutput && Pipewire.defaultAudioSink === menu.pendingOutput) {
                outputTimeout.stop();
                menu.pendingOutput = null;
                menu.outputMessage = "";
            }
        }
    }
    Timer {
        id: outputTimeout
        interval: 2000
        onTriggered: {
            if (menu.pendingOutput && Pipewire.defaultAudioSink !== menu.pendingOutput)
                menu.outputMessage = "This output could not be activated. Check that the device is connected and available.";
            menu.pendingOutput = null;
        }
    }
    onOpenedChanged: {
        if (opened) {
            scene.forceActiveFocus();
            scroll.contentY = 0;
            outputMessage = "";
            advanced = false;
        }
    }
    // Bind every playback node while open, including devices and streams added later.
    PwObjectTracker {
        objects: menu.opened || menu.pendingRoute ? menu.outputs.concat(menu.streams, Pipewire.defaultAudioSource ? [Pipewire.defaultAudioSource] : []) : []
    }
    AudioDevices {
        id: devices
        active: menu.opened || menu.pendingRoute !== null
        onActivationFailed: {
            menu.pendingRoute = null;
            routeTimeout.stop();
            menu.outputMessage = "This output could not be enabled. Please try again.";
        }
    }

    component Label: Text {
        color: "#B8B8B8"
        textFormat: Text.PlainText
        font {
            family: menu.theme.fontFamily
            pixelSize: 12
        }
        wrapMode: Text.WordWrap
    }
    component Divider: Rectangle {
        width: body.width
        height: 1
        color: "#303030"
    }

    BarComponents.BarMenuScene {
        id: scene
        opened: menu.opened
        Keys.onEscapePressed: {
            if (menu.advanced) {
                menu.advanced = false;
                scroll.contentY = 0;
            } else
                menu.opened = false;
        }
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
            anchors {
                top: parent.top
                topMargin: menu.theme.barMargin + menu.theme.barHeight + 8
            }
            x: Math.max(menu.theme.barMargin, Math.min(menu.anchorCenter - width / 2, (menu.screen?.width ?? menu.width) - width - menu.theme.barMargin))
            width: Math.min(400, (menu.screen?.width ?? menu.width) - 2 * menu.theme.barMargin)
            height: Math.min(body.implicitHeight + 86, menu.height - y - 16)
            radius: 16
            color: "#1D1D1D"
            border {
                width: 1
                color: "#383838"
            }
            // Consume empty panel clicks so only clicks outside dismiss it.
            MouseArea {
                anchors.fill: parent
            }

            Text {
                x: 22
                y: 18
                text: menu.advanced ? "Sound details" : "Sound"
                color: "#F8F9F9"
                font {
                    family: "serif"
                    pixelSize: 23
                }
            }
            Flickable {
                id: scroll
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                    leftMargin: 22
                    rightMargin: 22
                    topMargin: 64
                    bottomMargin: 22
                }
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                Column {
                    id: body
                    width: scroll.width
                    spacing: 18

                    VolumeControl {
                        width: parent.width
                        node: Pipewire.defaultAudioSink
                        title: "Main volume"
                        subtitle: node ? menu.friendlyName(node) : "No audio output connected"
                        fontFamily: menu.theme.fontFamily
                    }
                    VolumeControl {
                        width: parent.width
                        node: Pipewire.defaultAudioSource
                        title: "Microphone"
                        subtitle: node ? menu.deviceName(node) : "No microphone connected"
                        fontFamily: menu.theme.fontFamily
                    }
                    Divider {}
                    Column {
                        width: parent.width
                        spacing: 14
                        Label {
                            text: menu.advanced ? "Individual audio streams" : "Applications"
                            color: "#F8F9F9"
                        }
                        Label {
                            width: parent.width
                            visible: menu.advanced
                            text: "An app can play several sounds at once. Adjust each one separately here."
                        }
                        Label {
                            width: parent.width
                            visible: menu.streams.length === 0
                            text: "Apps appear here when they play audio."
                        }
                        Repeater {
                            model: !menu.opened ? [] : menu.advanced ? menu.streams.map(node => ({
                                        name: node.properties["application.name"] || node.description || node.name || "Application",
                                        nodes: [node]
                                    })) : menu.applications
                            VolumeControl {
                                required property var modelData
                                width: body.width
                                nodes: modelData.nodes
                                title: modelData.name
                                subtitle: menu.advanced ? (nodes[0]?.properties["media.name"] || nodes[0]?.name || "Audio stream") + " · " + nodes[0]?.id : ""
                                fontFamily: menu.theme.fontFamily
                            }
                        }
                    }
                    Divider {}
                    Column {
                        width: parent.width
                        spacing: 8
                        Label {
                            text: menu.advanced ? "All audio outputs" : "Play sound through"
                            color: "#F8F9F9"
                        }
                        Label {
                            width: parent.width
                            visible: menu.visibleOutputs.length === 0
                            text: Pipewire.ready ? "No audio outputs connected." : "Connecting to audio…"
                        }
                        Repeater {
                            model: menu.opened ? menu.visibleOutputs : []
                            Button {
                                id: outputButton
                                required property var modelData
                                readonly property bool selected: modelData.node !== null && Pipewire.defaultAudioSink === modelData.node
                                readonly property bool unavailable: modelData.unavailable
                                width: body.width
                                implicitHeight: deviceLabel.implicitHeight + 24
                                padding: 12
                                hoverEnabled: true
                                enabled: (!modelData.node || modelData.node.ready) && !unavailable && !devices.activating
                                Accessible.name: modelData.name
                                Accessible.description: unavailable ? "Not connected" : selected ? "Current output device" : "Use this output device"
                                onClicked: menu.selectChoice(modelData)
                                background: Rectangle {
                                    radius: 10
                                    color: outputButton.down ? "#41403A" : outputButton.hovered ? "#343434" : outputButton.selected ? "#302B25" : "#262626"
                                    border.width: outputButton.selected || outputButton.visualFocus ? 1 : 0
                                    border.color: "#D6B48C"
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 120
                                        }
                                    }
                                }
                                contentItem: Row {
                                    spacing: 10
                                    Text {
                                        width: 16
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: outputButton.selected ? "✓" : (outputButton.modelData.node && menu.pendingOutput === outputButton.modelData.node) || menu.pendingRoute?.key === outputButton.modelData.key ? "…" : "○"
                                        color: outputButton.selected ? "#D6B48C" : "#777777"
                                        font.pixelSize: 15
                                    }
                                    Label {
                                        id: deviceLabel
                                        width: outputButton.availableWidth - 26
                                        text: menu.advanced ? outputButton.modelData.description + (outputButton.unavailable ? "\nNot connected" : "") : outputButton.modelData.name
                                        color: outputButton.unavailable ? "#888888" : "#F8F9F9"
                                    }
                                }
                                HoverHandler {
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                        Label {
                            width: parent.width
                            visible: menu.outputMessage.length > 0
                            text: menu.outputMessage
                            color: "#EBA095"
                        }
                    }
                    Settings.SettingsButton {
                        width: parent.width
                        fontFamily: menu.theme.fontFamily
                        text: menu.advanced ? "‹  Back to simple controls" : "Advanced controls  ›"
                        onClicked: {
                            menu.advanced = !menu.advanced;
                            scroll.contentY = 0;
                        }
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }
}
