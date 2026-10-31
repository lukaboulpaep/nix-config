import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import "AudioModel.js" as AudioModel

Scope {
    id: devices
    required property bool active
    property var snapshotState: []
    readonly property var bluetoothNames: {
        const names = {};
        for (const adapter of Bluetooth.adapters.values)
            for (const device of adapter.devices.values)
                if (device.name)
                    names[device.address.toUpperCase()] = device.name;
        return names;
    }
    readonly property var details: AudioModel.outputDetails(snapshotState, bluetoothNames)
    readonly property var inactiveOutputs: AudioModel.inactiveOutputs(snapshotState, bluetoothNames)
    property var activating: null
    property bool waitingForNode: false
    signal activationFailed

    function refresh() {
        if (active && !snapshot.running)
            snapshot.running = true;
    }
    onActiveChanged: if (active)
        refresh()
    Component.onCompleted: refresh()
    function activate(choice) {
        if (profileSwitch.running || routeSwitch.running)
            return;
        activating = choice;
        activationTimeout.restart();
        profileSwitch.command = ["wpctl", "set-profile", String(choice.deviceId), String(choice.profileIndex)];
        profileSwitch.running = true;
    }
    Process {
        id: profileSwitch
        stderr: StdioCollector {
            id: profileError
        }
        onExited: code => {
            if (code !== 0) {
                devices.failActivation(profileError.text);
                return;
            }
            devices.waitingForNode = true;
            devices.refresh();
        }
    }
    function failActivation(message) {
        console.warn("Audio output activation failed: " + message);
        activationTimeout.stop();
        waitingForNode = false;
        activating = null;
        activationFailed();
    }
    Timer {
        interval: 100
        repeat: true
        running: devices.waitingForNode && devices.activating !== null
        onTriggered: {
            const choice = devices.activating;
            const node = Pipewire.nodes.values.find(n => n.audio && n.isSink && !n.isStream && n.ready && String(n.properties["device.id"]) === String(choice.deviceId) && String(n.properties["card.profile.device"]) === String(choice.profileDevice));
            if (!node)
                return;
            devices.waitingForNode = false;
            // set-profile takes a card ID; set-route takes a playback node ID.
            routeSwitch.command = ["wpctl", "set-route", String(node.id), String(choice.routeIndex)];
            routeSwitch.running = true;
        }
    }
    Timer {
        id: activationTimeout
        interval: 4500
        onTriggered: devices.failActivation("Timed out waiting for the playback output")
    }
    Process {
        id: routeSwitch
        stderr: StdioCollector {
            id: routeError
        }
        onExited: code => {
            if (code !== 0) {
                devices.failActivation(routeError.text);
                return;
            }
            activationTimeout.stop();
            devices.activating = null;
            devices.refresh();
        }
    }
    Timer {
        interval: 3000
        running: devices.active
        repeat: true
        onTriggered: devices.refresh()
    }
    Process {
        id: snapshot
        command: ["pw-dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    devices.snapshotState = JSON.parse(text);
                } catch (_) {
                    devices.snapshotState = [];
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                devices.snapshotState = [];
        }
    }
}
