import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: service
    property var command: ["desktop-displays", "--serve"]
    property bool ready: false
    property bool busy: false
    property var displays: []
    property var layout: ({
            mode: "extend",
            primary: "",
            positions: {}
        })
    property var profiles: []
    property bool externalMain: false
    property bool pending: false
    property int remaining: 0
    property string error: ""
    property string message: ""
    property int generation: 0
    property string pointerScreen: ""
    property int restartAttempts: 0
    signal updated
    signal layoutChanging
    function send(action, values = {}) {
        if (!ready || busy)
            return;
        if (["apply", "load", "revert"].includes(action))
            layoutChanging();
        busy = true;
        backend.write(JSON.stringify(Object.assign({
            action: action
        }, values)) + "\n");
    }
    function refresh() {
        if (!ready)
            retry();
        else if (!busy)
            send("status");
    }
    function retry() {
        if (!backend.running) {
            service.error = "";
            startupTimeout.restart();
            backend.running = true;
        }
    }
    Component.onCompleted: startupTimeout.start()
    Timer {
        id: startupTimeout
        interval: 3000
        onTriggered: if (!service.ready && !service.error)
            service.error = "Display controls are unavailable. Activate the updated desktop configuration, then retry."
    }
    Timer {
        id: restartTimer
        interval: 700
        onTriggered: service.retry()
    }
    Process {
        id: backend
        // Keep layout transactions outside the UI so rollback survives a panel failure.
        command: service.command
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                let result;
                try {
                    result = JSON.parse(data);
                } catch (_) {
                    return;
                }
                service.busy = false;
                if (result.event === "state") {
                    service.ready = true;
                    service.restartAttempts = 0;
                    startupTimeout.stop();
                    service.displays = result.displays;
                    service.layout = result.layout;
                    service.profiles = result.profiles;
                    service.externalMain = result.externalMain;
                    service.pending = result.pending;
                    service.remaining = result.remaining;
                    service.error = result.error || "";
                    service.message = result.message || "";
                    service.generation = result.generation || 0;
                    service.pointerScreen = result.pointerScreen || "";
                    service.updated();
                } else if (result.event === "error") {
                    service.error = result.error;
                    service.updated();
                }
            }
        }
        onExited: {
            service.ready = false;
            service.busy = false;
            service.pending = false;
            service.updated();
            if (!service.error)
                service.error = "Display controls are unavailable. Activate the updated desktop configuration, then retry.";
            if (service.restartAttempts++ < 3)
                restartTimer.start();
        }
    }
}
