import QtQuick
import QtQuick.Controls
import "../settings" as Settings

Column {
    id: control
    property var node: null
    property var nodes: node ? [node] : []
    required property string title
    required property string fontFamily
    property string subtitle: ""
    readonly property var activeNodes: nodes.filter(n => n?.ready && n.audio)
    readonly property bool available: activeNodes.length > 0
    readonly property real volume: available ? Math.max(...activeNodes.map(n => n.audio.volume)) : 0
    readonly property bool muted: available && activeNodes.every(n => n.audio.muted)
    function setVolume(value) {
        for (const n of activeNodes) {
            n.audio.volume = value;
            if (value > 0)
                n.audio.muted = false;
        }
    }
    function toggleMute() {
        const next = !muted;
        for (const n of activeNodes)
            n.audio.muted = next;
    }
    spacing: 6

    Row {
        width: parent.width
        spacing: 12
        Text {
            width: parent.width - percentage.width - parent.spacing
            text: control.title
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: "#F8F9F9"
            font {
                family: control.fontFamily
                pixelSize: 13
                weight: Font.Medium
            }
        }
        Text {
            id: percentage
            width: 42
            text: control.available ? Math.round(control.volume * 100) + "%" : "—"
            horizontalAlignment: Text.AlignRight
            color: control.muted ? "#B8B8B8" : "#D6B48C"
            font {
                family: control.fontFamily
                pixelSize: 13
            }
        }
    }
    Text {
        width: parent.width
        visible: text.length > 0
        text: control.subtitle
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: "#B8B8B8"
        font {
            family: control.fontFamily
            pixelSize: 11
        }
    }
    Row {
        width: parent.width
        spacing: 12
        Settings.SettingsButton {
            width: 72
            implicitWidth: 72
            implicitHeight: 32
            padding: 6
            fontFamily: control.fontFamily
            enabled: control.available
            text: control.muted ? "Unmute" : "Mute"
            textColor: control.muted ? "#D6B48C" : "#F8F9F9"
            Accessible.name: text + " " + control.title
            onClicked: control.toggleMute()
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
        Slider {
            id: slider
            width: parent.width - 84
            height: 32
            from: 0
            to: 1
            stepSize: 0.01
            enabled: control.available
            Accessible.name: control.title + " volume"
            Binding {
                target: slider
                property: "value"
                value: control.volume
                when: !slider.pressed
                restoreMode: Binding.RestoreNone
            }
            onMoved: control.setVolume(value)
            background: Rectangle {
                x: slider.leftPadding
                y: (slider.height - height) / 2
                width: slider.availableWidth
                height: 5
                radius: 3
                color: "#383838"
                Rectangle {
                    width: parent.width * slider.visualPosition
                    height: parent.height
                    radius: 3
                    color: control.muted ? "#777777" : "#D6B48C"
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: (slider.height - height) / 2
                width: 14
                height: 14
                radius: 7
                color: slider.pressed || slider.visualFocus ? "#D6B48C" : "#F8F9F9"
                opacity: slider.enabled ? 1 : 0.4
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
