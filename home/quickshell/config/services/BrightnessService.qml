pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io

import "../core" as Core

// BrightnessService

Singleton {
    id: root

    // 0..100.
    property int level: 0

    readonly property real fraction: root.level / 100

    // False until a reading actually succeeds, so a desktop with no backlight can be detected rather than showing a fake 0%.
    property bool available: false

    readonly property int stepSize: 5

    // brightnessctl refuses to write below this raw hardware value. On this
    // panel and the exponent-4 curve that becomes a visible floor near 25%.
    readonly property int minRaw: 2

    // brightnessctl reports percentages on this perceptual curve, while sysfs
    // exposes the raw linear value. Match the keyboard path's brightnessctl
    // curve so the popup and OSD report the value users actually selected.
    readonly property real curveExponent: 4

    readonly property real minimumFraction: root.maxRaw > 0 ? Math.pow(root.minRaw / root.maxRaw, 1 / root.curveExponent) : 0

    readonly property int minimumLevel: Math.round(root.minimumFraction * 100)

    // Discovered hardware

    // e.g. "amdgpu_bl1" or "intel_backlight".
    property string device: ""

    // Raw scale maximum, NOT a percentage.
    property int maxRaw: 0

    property int probeTries: 0

    // A local change updates the number instantly and briefly suppresses readings, so a poll landing mid-write cannot snap the value back and
    property double ignoreReadsUntil: 0

    // Single entry point for every reading

    function ingest(percent) {
        if (percent < 0)
            return;
        root.available = true;

        if (root.writer.running || root.pendingLevel >= 0 || Date.now() < root.ignoreReadsUntil)
            return;
        const value = Math.max(0, Math.min(100, Math.round(percent)));

        // Only assign on a real change.
        if (value !== root.level)
            root.level = value;
    }

    function percentFromRaw(raw) {
        if (root.maxRaw <= 0)
            return -1;

        const linear = Math.max(0, Math.min(1, raw / root.maxRaw));

        return Math.pow(linear, 1 / root.curveExponent) * 100;
    }

    // One-shot discovery

    property Process probe: Process {
        command: ["brightnessctl", "-e" + root.curveExponent, "-m"]

        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0];

                if (!line)
                    return;
                const fields = line.split(",");

                if (fields.length < 5)
                    return;
                const max = parseInt(fields[4]);

                if (isNaN(max) || max <= 0)
                    return;
                root.device = fields[0];
                root.maxRaw = max;

                // Seed the value immediately so the bar is correct on the very first frame, before the first file read lands.
                root.ingest(parseInt(String(fields[3]).replace("%", "")));
            }
        }
    }

    function runProbe() {
        root.probeTries += 1;
        root.probe.running = false;
        root.probe.running = true;
    }

    // The cheap reading path

    property FileView backlightFile: FileView {
        path: root.device === "" ? "" : "/sys/class/backlight/" + root.device + "/actual_brightness"

        onLoaded: {
            if (root.maxRaw <= 0)
                return;
            const raw = parseInt(root.backlightFile.text().trim());

            if (isNaN(raw))
                return;
            root.ingest(root.percentFromRaw(raw));
        }
    }

    // Actions

    // Writes are absolute and serialised. Repeating function-key events can
    // otherwise launch several relative brightnessctl processes that all read
    // the same old value and then finish out of order.
    property int pendingLevel: -1

    property int writingLevel: -1

    property Process writer: Process {
        onExited: function (exitCode) {
            root.ignoreReadsUntil = Date.now() + 120;

            if (root.pendingLevel >= 0) {
                Qt.callLater(root.startWrite);
                return;
            }

            root.writingLevel = -1;
            root.settleTimer.restart();
        }
    }

    function startWrite() {
        if (root.writer.running || root.pendingLevel < 0)
            return;

        root.writingLevel = root.pendingLevel;
        root.pendingLevel = -1;
        root.writer.command = ["brightnessctl", "-e" + root.curveExponent, "-n" + root.minRaw, "set", root.writingLevel + "%"];
        root.writer.running = true;
    }

    // Predict so the click feels instant, then let the file read (within ~100ms) settle the true value.
    function applyPredicted(next) {
        const floor = root.available ? root.minimumLevel : 0;
        const clamped = Math.max(floor, Math.min(100, Math.round(next)));

        root.ignoreReadsUntil = Date.now() + 120;

        if (clamped !== root.level) {
            root.level = clamped;
        } else {
            // Already at the rail, so onLevelChanged will not fire.
            Core.OsdController.show("brightness", root.fraction, false);
        }
    }

    function step(up) {
        root.setPercent(root.level + (up ? root.stepSize : -root.stepSize));
    }

    function setPercent(percent) {
        const floor = root.available ? root.minimumLevel : 0;
        const target = Math.max(floor, Math.min(100, Math.round(percent)));

        root.applyPredicted(target);
        root.pendingLevel = target;
        root.startWrite();
    }

    function refresh() {
        if (root.device === "")
            root.runProbe();
        else
            root.backlightFile.reload();
    }

    // OSD trigger

    // Use the changed property directly. The derived `fraction` binding can
    // still contain the previous level while this signal handler is running,
    // which made the OSD lag one step behind the correctly bound popup.
    onLevelChanged: Core.OsdController.show("brightness", root.level / 100, false)

    // Timers

    // 100ms of a plain file read.
    property Timer poll: Timer {
        interval: 100

        running: root.device !== ""
        repeat: true

        onTriggered: root.backlightFile.reload()
    }

    property Timer settleTimer: Timer {
        interval: 140

        repeat: false

        onTriggered: root.backlightFile.reload()
    }

    // Only runs until the device is found, and gives up rather than spawning brightnessctl forever on a machine that has no backlight at all.
    property Timer discoveryRetry: Timer {
        interval: 1000

        running: root.device === "" && root.probeTries < 5

        repeat: true

        onTriggered: root.runProbe()
    }

    Component.onCompleted: root.runProbe()
}
