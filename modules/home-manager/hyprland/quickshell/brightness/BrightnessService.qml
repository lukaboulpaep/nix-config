import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: service
    property bool active: false
    readonly property int minimum: 10
    property alias displays: rows
    property var values: ({})
    property int controllableCount: 0
    property int combinedValue: minimum
    property bool mixedValues: false
    property int displayErrorCount: 0
    property string error: ""
    property var pending: ({})
    property string writingId: ""
    property bool writerReady: false
    readonly property bool busy: reader.running || writingId.length > 0
    property bool refreshPending: false
    readonly property string screenSignature: Quickshell.screens.map(s => s.name).join("|")
    ListModel {
        id: rows
    }

    function publishValues() {
        const result = {};
        const levels = [];
        let errors = 0;
        for (let i = 0; i < rows.count; i++) {
            const display = rows.get(i);
            result[display.connector] = display.value;
            if (display.supported && display.value >= 0)
                levels.push(display.value);
            if (display.error)
                errors++;
        }
        values = result;
        controllableCount = levels.length;
        combinedValue = levels.length ? Math.round(levels.reduce((a, b) => a + b, 0) / levels.length) : minimum;
        mixedValues = levels.length > 1 && Math.min(...levels) !== Math.max(...levels);
        displayErrorCount = errors;
    }
    function indexOf(id) {
        for (let i = 0; i < rows.count; i++)
            if (rows.get(i).displayId === id)
                return i;
        return -1;
    }
    function refresh() {
        if (busy || Object.keys(pending).length) {
            refreshPending = true;
            return;
        }
        refreshPending = false;
        reader.running = true;
    }
    function queueBrightness(id, value, verify) {
        const index = indexOf(id);
        if (index < 0 || !rows.get(index).supported)
            return;
        const next = Math.max(minimum, Math.min(100, Math.round(value)));
        pending = Object.assign({}, pending, {
            [id]: {
                value: next,
                verify: verify
            }
        });
        rows.setProperty(index, "value", next);
        rows.setProperty(index, "error", "");
    }
    function setBrightness(id, value, verify = true) {
        queueBrightness(id, value, verify);
        sendChanges(verify);
    }
    function setAllBrightness(value, verify = true) {
        for (let i = 0; i < rows.count; i++)
            queueBrightness(rows.get(i).displayId, value, verify);
        sendChanges(verify);
    }
    function sendChanges(verify) {
        publishValues();
        // Start once: dragging must not continually postpone the hardware write.
        if (verify)
            flush();
        else
            throttle.start();
    }
    function flush() {
        if (busy || !writerReady)
            return;
        const ids = Object.keys(pending);
        if (!ids.length) {
            if (refreshPending)
                refresh();
            return;
        }
        writingId = ids[0];
        const next = pending[writingId];
        const remaining = Object.assign({}, pending);
        delete remaining[writingId];
        pending = remaining;
        writer.write(JSON.stringify({
            id: writingId,
            value: next.value,
            verify: next.verify
        }) + "\n");
    }
    function writeFinished(result) {
        const index = indexOf(writingId);
        if (index >= 0) {
            if (result.error) {
                rows.setProperty(index, "error", "The display didn’t apply the change. Check its connection or monitor settings.");
                if (!(writingId in pending))
                    rows.setProperty(index, "value", rows.get(index).confirmed);
            } else {
                if (result.verified)
                    rows.setProperty(index, "confirmed", result.value);
                if (!(writingId in pending))
                    rows.setProperty(index, "value", result.value);
            }
        }
        writingId = "";
        publishValues();
        Qt.callLater(flush);
    }
    onActiveChanged: if (active)
        refresh()
    onScreenSignatureChanged: refresh()
    Component.onCompleted: refresh()
    Timer {
        id: throttle
        interval: 40
        onTriggered: service.flush()
    }
    Timer {
        interval: 8000
        running: service.active
        repeat: true
        onTriggered: service.refresh()
    }
    Process {
        id: reader
        command: ["desktop-brightness", "list"]
        stdout: StdioCollector {
            id: readOutput
        }
        onExited: code => {
            try {
                const result = JSON.parse(readOutput.text);
                if (code !== 0 || !result.displays)
                    throw new Error(result.error || "Could not read display brightness.");
                service.error = "";
                const ids = result.displays.map(d => d.id);
                for (let i = rows.count - 1; i >= 0; i--)
                    if (!ids.includes(rows.get(i).displayId))
                        rows.remove(i);
                for (const display of result.displays) {
                    const index = service.indexOf(display.id);
                    const record = {
                        displayId: display.id,
                        connector: display.connector,
                        name: display.name,
                        value: display.value ?? -1,
                        confirmed: display.value ?? -1,
                        supported: display.supported,
                        message: display.message,
                        error: ""
                    };
                    if (index < 0)
                        rows.append(record);
                    else if (!(display.id in service.pending))
                        rows.set(index, record);
                }
                service.publishValues();
            } catch (_) {
                service.error = "Brightness controls are unavailable. Try again in a moment.";
            }
            Qt.callLater(service.flush);
        }
    }
    Process {
        id: writer
        command: ["desktop-brightness", "serve"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const result = JSON.parse(data);
                    if (result.ready) {
                        service.writerReady = true;
                        service.flush();
                    } else
                        service.writeFinished(result);
                } catch (_) {
                    service.writeFinished({
                        error: "Invalid brightness response"
                    });
                }
            }
        }
        onExited: {
            service.writerReady = false;
            if (service.writingId)
                service.writeFinished({
                    error: "Brightness helper stopped"
                });
            restartWriter.start();
        }
    }
    Timer {
        id: restartWriter
        interval: 1000
        onTriggered: writer.running = true
    }
    Timer {
        interval: 15000
        running: writer.running && (!service.writerReady || service.writingId.length > 0)
        onTriggered: writer.signal(9)
    }
}
