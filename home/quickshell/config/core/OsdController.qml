pragma Singleton

import QtQuick

// OsdController

QtObject {
    id: root

    property string kind: ""

    // Always normalised 0..1.
    property real value: 0

    property bool muted: false

    // Empty means a global control such as audio and is shown on the primary
    // bar. Monitor-specific controls such as brightness name their output.
    property string monitor: ""

    readonly property bool active: root.kind !== ""

    // How long the readout stays up after the last change.
    readonly property int holdDuration: 1600

    // Startup guard

    property bool armed: false

    property Timer armTimer: Timer {
        interval: 1500

        running: true
        repeat: false

        onTriggered: root.armed = true
    }

    // Hold timer

    property Timer hideTimer: Timer {
        interval: root.holdDuration

        repeat: false

        onTriggered: root.hide()
    }

    // API

    // Raise (or refresh) an OSD.
    function show(kind, value, muted, monitor) {
        if (!root.armed)
            return;
        root.kind = kind;

        root.value = Math.max(0, Math.min(1, value));

        root.muted = muted === true;

        root.monitor = monitor === undefined || monitor === null ? "" : String(monitor);

        root.hideTimer.restart();
    }

    function hide() {
        root.hideTimer.stop();
        root.kind = "";
        root.monitor = "";
    }
}
