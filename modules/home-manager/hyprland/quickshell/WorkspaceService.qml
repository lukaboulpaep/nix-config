import QtQuick
import Quickshell
import Quickshell.Hyprland
import "WorkspaceModel.js" as Model

Scope {
    id: service
    required property var displays
    readonly property string mainMonitor: displays.displays.find(d => d.id === displays.layout.primary)?.name ?? displays.displays.find(d => d.internal)?.name ?? Hyprland.monitors.values[0]?.name ?? ""
    readonly property var assignments: {
        const result = {};
        for (const [key, id] of Object.entries(displays.layout.workspaces || {})) {
            const name = displays.displays.find(d => d.id === id)?.name;
            if (name)
                result[key] = name;
        }
        return result;
    }
    readonly property var entries: Model.entries(Hyprland.workspaces.values.map(ws => ({
                id: ws.id,
                name: ws.name,
                monitor: ws.monitor?.name || "",
                windowCount: ws.toplevels.values.length
            })), Hyprland.monitors.values.map(m => ({
                name: m.name,
                activeWorkspace: m.activeWorkspace?.id
            })), mainMonitor, assignments)

    // A workspace move can also change the source monitor's visible workspace.
    // Refresh both models once per burst, after the compositor finishes the move.
    Timer {
        id: refreshAfterMove
        interval: 25
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshMonitors();
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["moveworkspace", "moveworkspacev2", "monitoradded", "monitoraddedv2", "monitorremoved", "configreloaded"].includes(event.name))
                refreshAfterMove.restart();
        }
    }
}
