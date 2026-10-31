import QtQuick
import Quickshell
import Quickshell.Io
import "ConnectionModel.js" as Model

Scope {
    id: operation
    property alias busy: process.running
    property string deviceName: ""
    property string devicePath: ""
    property string action: ""
    property string error: ""
    property string progress: ""
    property string prompt: ""
    property string code: ""
    property bool completed: false
    signal succeeded(string action, string path)
    function run(action, target, value = "") {
        if (busy || !target)
            return;
        operation.action = action;
        deviceName = Model.bluetoothLabel(target);
        devicePath = target.dbusPath;
        error = "";
        prompt = "";
        code = "";
        completed = false;
        progress = action === "pair" ? "Pairing…" : action === "connect" ? "Connecting…" : action === "disconnect" ? "Disconnecting…" : "Applying…";
        process.command = ["desktop-bluetooth", action, devicePath].concat(action === "rename" ? [value] : []);
        process.running = true;
    }
    function answer(value) {
        process.write(JSON.stringify({
            value: value
        }) + "\n");
    }
    function cancel() {
        if (busy && action === "pair")
            process.write('{"cancel":true}\n');
    }
    Process {
        id: process
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                let result;
                try {
                    result = JSON.parse(data);
                } catch (_) {
                    return;
                }
                if (result.event === "prompt") {
                    operation.prompt = result.kind;
                    operation.code = result.code || "";
                } else if (result.event === "progress") {
                    operation.prompt = "";
                    operation.progress = result.message;
                } else if (result.event === "done") {
                    operation.completed = true;
                    operation.prompt = "";
                    operation.progress = "";
                    operation.error = result.ok ? "" : result.error;
                    if (result.ok)
                        operation.succeeded(operation.action, operation.devicePath);
                }
            }
        }
        onExited: code => {
            operation.prompt = "";
            operation.progress = "";
            if (!operation.completed)
                operation.error = "Bluetooth controls couldn’t start. The desktop Bluetooth helper may need to be installed.";
        }
    }
}
