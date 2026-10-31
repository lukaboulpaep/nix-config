import QtQuick
import Quickshell
import Quickshell.Io
import "BatteryModel.js" as Model

Scope {
    id: service
    property bool active: false
    property var profiles: []
    property string profile: ""
    property string requested: ""
    property string queued: ""
    property string error: ""
    property bool available: false
    readonly property bool busy: reader.running || writer.running
    function refresh() {
        if (!busy)
            reader.running = true;
    }
    function select(id) {
        if (writer.running || requested || !available || id === profile || !profiles.some(p => p.id === id))
            return;
        // A periodic status read must not swallow a click.
        if (reader.running) {
            queued = id;
            return;
        }
        requested = id;
        error = "";
        writer.command = ["powerprofilesctl", "set", id];
        writer.running = true;
    }
    onActiveChanged: if (active)
        refresh()
    Component.onCompleted: refresh()
    Timer {
        interval: 5000
        running: service.active
        repeat: true
        onTriggered: service.refresh()
    }
    Process {
        id: reader
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 || exit 127; exec powerprofilesctl list"]
        environment: ({
                LC_ALL: "C",
                NO_COLOR: "1"
            })
        stdout: StdioCollector {
            id: profileOutput
        }
        onExited: code => {
            const result = Model.parseProfiles(profileOutput.text);
            service.available = code === 0 && result.profiles.length > 0 && result.active.length > 0;
            service.profiles = service.available ? result.profiles : [];
            service.profile = service.available ? result.active : "";
            if (service.requested) {
                service.error = service.profile === service.requested ? "" : "The power mode didn’t change. Try again.";
                service.requested = "";
            }
            if (service.queued) {
                const next = service.queued;
                service.queued = "";
                Qt.callLater(() => service.select(next));
            }
        }
    }
    Process {
        id: writer
        onExited: code => {
            if (code !== 0) {
                service.error = "Couldn’t change power mode. Check that the power service is available.";
                service.requested = "";
            }
            Qt.callLater(service.refresh);
        }
    }
}
