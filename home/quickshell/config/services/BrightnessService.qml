pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Hyprland
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

    // DDC/CI values for external outputs, keyed by Hyprland connector name.
    // A value appears after the first successful brightness command/read.
    property var externalLevels: ({})

    property string ddcMonitor: ""
    property var ddcSelector: []
    property int ddcPendingDelta: 0
    property int ddcPendingAbsolute: -1
    property int ddcReadLevel: -1

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

    function monitorByName(name) {
        const monitors = Hyprland.monitors.values;

        for (let i = 0; i < monitors.length; i++) {
            if (monitors[i].name === name)
                return monitors[i];
        }

        return null;
    }

    function targetMonitorName(requested) {
        if (requested && requested.length > 0)
            return requested;

        return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : DisplayService.internalMonitor;
    }

    function isInternalMonitor(name) {
        return name === DisplayService.internalMonitor;
    }

    function levelFor(name) {
        const monitorName = root.targetMonitorName(name);

        if (root.isInternalMonitor(monitorName))
            return root.level;

        const value = root.externalLevels[monitorName];

        return typeof value === "number" ? value : -1;
    }

    function fractionFor(name) {
        const value = root.levelFor(name);

        return value < 0 ? 0 : value / 100;
    }

    function availableFor(name) {
        const monitorName = root.targetMonitorName(name);

        return root.isInternalMonitor(monitorName) ? root.available : root.monitorByName(monitorName) !== null;
    }

    function minimumFractionFor(name) {
        return root.isInternalMonitor(name) ? root.minimumFraction : 0;
    }

    function updateExternalLevel(name, value) {
        const levels = {};

        for (const key in root.externalLevels)
            levels[key] = root.externalLevels[key];

        levels[name] = Math.max(0, Math.min(100, Math.round(value)));
        root.externalLevels = levels;
    }

    function selectorFor(monitor) {
        if (!monitor)
            return [];

        const info = monitor.lastIpcObject || {};
        const model = info.model ? String(info.model).trim() : "";
        const serial = info.serial ? String(info.serial).trim() : "";
        const selector = [];

        if (model.length === 0)
            return selector;

        selector.push("--model", model);

        if (serial.length > 0)
            selector.push("--sn", serial);

        return selector;
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
    function applyPredicted(next, monitorName) {
        const floor = root.available ? root.minimumLevel : 0;
        const clamped = Math.max(floor, Math.min(100, Math.round(next)));

        root.ignoreReadsUntil = Date.now() + 120;

        if (clamped !== root.level) {
            root.level = clamped;
        }

        // Only explicit user actions raise the OSD. Passive sysfs changes
        // include the internal panel dropping to zero while its lid closes.
        Core.OsdController.show("brightness", clamped / 100, false, monitorName);
    }

    function step(up, requestedMonitor) {
        const monitorName = root.targetMonitorName(requestedMonitor);

        if (root.isInternalMonitor(monitorName)) {
            root.setPercent(root.level + (up ? root.stepSize : -root.stepSize), monitorName);
            return;
        }

        root.queueDdcDelta(root.monitorByName(monitorName), up ? root.stepSize : -root.stepSize);
    }

    function setPercent(percent, requestedMonitor) {
        const monitorName = root.targetMonitorName(requestedMonitor);

        if (!root.isInternalMonitor(monitorName)) {
            root.queueDdcAbsolute(root.monitorByName(monitorName), percent);
            return;
        }

        const floor = root.available ? root.minimumLevel : 0;
        const target = Math.max(floor, Math.min(100, Math.round(percent)));

        root.applyPredicted(target, monitorName);
        root.pendingLevel = target;
        root.startWrite();
    }

    function refresh() {
        if (root.device === "")
            root.runProbe();
        else
            root.backlightFile.reload();
    }

    // External DDC/CI actions

    function selectDdcMonitor(monitor) {
        if (!monitor || root.isInternalMonitor(monitor.name))
            return false;

        const selector = root.selectorFor(monitor);

        if (selector.length === 0)
            return false;

        if ((root.ddcWriter.running || root.ddcReader.running) && root.ddcMonitor !== monitor.name)
            return false;

        root.ddcMonitor = monitor.name;
        root.ddcSelector = selector;
        return true;
    }

    function queueDdcDelta(monitor, delta) {
        if (!root.selectDdcMonitor(monitor))
            return;

        root.ddcPendingAbsolute = -1;
        root.ddcPendingDelta += delta;
        root.startDdcWrite();
    }

    function queueDdcAbsolute(monitor, level) {
        if (!root.selectDdcMonitor(monitor))
            return;

        root.ddcPendingAbsolute = Math.max(0, Math.min(100, Math.round(level)));
        root.ddcPendingDelta = 0;
        root.startDdcWrite();
    }

    function startDdcWrite() {
        if (root.ddcWriter.running || root.ddcReader.running || root.ddcMonitor.length === 0)
            return;

        const command = ["ddcutil", "--noverify"].concat(root.ddcSelector).concat(["setvcp", "10"]);

        if (root.ddcPendingAbsolute >= 0) {
            command.push(String(root.ddcPendingAbsolute));
            root.ddcPendingAbsolute = -1;
        } else if (root.ddcPendingDelta !== 0) {
            const delta = root.ddcPendingDelta;

            root.ddcPendingDelta = 0;
            command.push(delta > 0 ? "+" : "-", String(Math.abs(delta)));
        } else {
            return;
        }

        root.ddcWriter.command = command;
        root.ddcWriter.running = true;
    }

    function startDdcRead() {
        root.ddcReadLevel = -1;
        root.ddcReader.command = ["ddcutil", "--terse"].concat(root.ddcSelector).concat(["getvcp", "10"]);
        root.ddcReader.running = true;
    }

    function finishDdcBatch() {
        if (root.ddcPendingAbsolute >= 0 || root.ddcPendingDelta !== 0) {
            Qt.callLater(root.startDdcWrite);
            return;
        }

        root.ddcMonitor = "";
        root.ddcSelector = [];
    }

    property Process ddcWriter: Process {
        onExited: function (exitCode) {
            if (exitCode === 0) {
                root.startDdcRead();
                return;
            }

            root.finishDdcBatch();
        }
    }

    property Process ddcReader: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/);

                if (!match)
                    return;

                const current = parseInt(match[1]);
                const maximum = parseInt(match[2]);

                if (!isNaN(current) && !isNaN(maximum) && maximum > 0)
                    root.ddcReadLevel = Math.round(current / maximum * 100);
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0 && root.ddcReadLevel >= 0) {
                root.updateExternalLevel(root.ddcMonitor, root.ddcReadLevel);
                Core.OsdController.show("brightness", root.ddcReadLevel / 100, false, root.ddcMonitor);
            }

            root.finishDdcBatch();
        }
    }

    property IpcHandler ipc: IpcHandler {
        target: "brightness"

        function step(direction: string): void {
            root.step(direction === "up", "");
        }
    }

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
