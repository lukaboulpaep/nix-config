pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Display hot-plug policy
//
// The persisted bar preference decides whether a newly connected external
// output stays empty or receives all numbered workspaces. A returning internal
// panel is different: reopening the lid must not reclaim those workspaces.

QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string modePath: root.home + "/.config/aurora/display-connect-mode"
    readonly property string internalMonitorPath: root.home + "/.config/aurora/internal-monitor"

    property bool ready: false
    property string pendingExternalMonitor: ""
    property var pendingRemovedWorkspaceIds: []

    property FileView modeFile: FileView {
        path: root.modePath
        watchChanges: true
        blockLoading: true
        printErrors: false

        onFileChanged: this.reload()
    }

    property FileView internalMonitorFile: FileView {
        path: root.internalMonitorPath
        watchChanges: true
        blockLoading: true
        printErrors: false

        onFileChanged: this.reload()
    }

    readonly property string internalMonitor: {
        const raw = root.internalMonitorFile.text()

        if (raw && raw.trim().length > 0)
            return raw.trim()

        // Development instances run directly from the repository before the
        // host-generated file is deployed. Keep that preview useful without
        // hard-coding this ThinkPad's exact connector name.
        const monitors = Hyprland.monitors.values

        for (let i = 0; i < monitors.length; i++) {
            const name = monitors[i].name

            if (name.indexOf("eDP-") === 0 || name.indexOf("LVDS-") === 0)
                return name
        }

        return ""
    }

    readonly property bool transferOnConnect: {
        const raw = root.modeFile.text()

        return raw && (raw.trim() === "transfer" || raw.trim() === "present")
    }

    readonly property string modeLabel: root.transferOnConnect ? "Transfer" : "Stay"

    readonly property string primaryMonitor: {
        if (root.monitorIsActive(root.internalMonitor))
            return root.internalMonitor

        const monitors = Hyprland.monitors.values

        return monitors.length > 0 ? monitors[0].name : ""
    }

    readonly property int externalMonitorCount: {
        const monitors = Hyprland.monitors.values
        let count = 0

        for (let i = 0; i < monitors.length; i++) {
            if (monitors[i].name !== root.internalMonitor)
                count++
        }

        return count
    }

    function setTransferOnConnect(enabled) {
        root.modeFile.setText(enabled ? "transfer\n" : "stay\n")
    }

    function toggleTransferOnConnect() {
        root.setTransferOnConnect(!root.transferOnConnect)
    }

    function isNumberedWorkspace(workspace) {
        return workspace && workspace.id >= 1 && workspace.id <= 10
    }

    function monitorIsActive(name) {
        if (!name || name.length === 0)
            return false

        const monitors = Hyprland.monitors.values

        for (let i = 0; i < monitors.length; i++) {
            if (monitors[i].name === name)
                return true
        }

        return false
    }

    function preferredExternalMonitor() {
        const monitors = Hyprland.monitors.values
        let name = ""

        for (let i = 0; i < monitors.length; i++) {
            if (monitors[i].name !== root.internalMonitor)
                name = monitors[i].name
        }

        return name
    }

    function directionalMonitor(direction) {
        const source = Hyprland.focusedMonitor

        if (!source)
            return ""

        const monitors = Hyprland.monitors.values
        const sourceX = source.x + source.width / 2
        const sourceY = source.y + source.height / 2
        let bestName = ""
        let bestDistance = Number.POSITIVE_INFINITY

        for (let i = 0; i < monitors.length; i++) {
            const monitor = monitors[i]

            if (monitor.name === source.name)
                continue

            const dx = monitor.x + monitor.width / 2 - sourceX
            const dy = monitor.y + monitor.height / 2 - sourceY
            const matches = (direction === "l" && dx < 0)
                || (direction === "r" && dx > 0)
                || (direction === "u" && dy < 0)
                || (direction === "d" && dy > 0)

            if (!matches)
                continue

            const distance = dx * dx + dy * dy

            if (distance < bestDistance) {
                bestDistance = distance
                bestName = monitor.name
            }
        }

        return bestName
    }

    function luaQuote(value) {
        return "\"" + String(value).replace(/\\/g, "\\\\").replace(/\"/g, "\\\"") + "\""
    }

    function moveWorkspace(workspaceId, monitorName) {
        if (workspaceId < 1 || workspaceId > 10 || !root.monitorIsActive(monitorName))
            return

        const expression = "hl.dispatch(hl.dsp.workspace.move({ workspace = "
            + workspaceId
            + ", monitor = "
            + root.luaQuote(monitorName)
            + " }))"

        Quickshell.execDetached(["hyprctl", "eval", expression])
    }

    function numberedWorkspaceIdsOn(monitorName, exceptId) {
        const workspaces = Hyprland.workspaces.values
        const ids = []

        for (let i = 0; i < workspaces.length; i++) {
            const workspace = workspaces[i]

            if (!root.isNumberedWorkspace(workspace) || workspace.id === exceptId)
                continue

            if (monitorName && (!workspace.monitor || workspace.monitor.name !== monitorName))
                continue

            ids.push(workspace.id)
        }

        return ids
    }

    function moveIds(ids, monitorName) {
        if (!root.monitorIsActive(monitorName))
            return

        for (let i = 0; i < ids.length; i++)
            root.moveWorkspace(ids[i], monitorName)
    }

    function moveIdsHome(ids) {
        root.moveIds(ids, root.internalMonitor)
    }

    function moveAllNumberedTo(monitorName) {
        root.moveIds(root.numberedWorkspaceIdsOn("", 0), monitorName)
    }

    function moveAllNumberedHome() {
        root.moveAllNumberedTo(root.internalMonitor)
    }

    function moveAllNumberedDirectional(direction) {
        const monitor = root.directionalMonitor(direction)

        if (monitor.length > 0)
            root.moveAllNumberedTo(monitor)
    }

    function settleAddedMonitor() {
        WallpaperService.reapply()

        const external = root.pendingExternalMonitor

        if (root.transferOnConnect && root.monitorIsActive(external)) {
            root.moveAllNumberedTo(external)
            root.pendingExternalMonitor = ""
            return
        }

        if (!root.transferOnConnect)
            root.moveAllNumberedHome()

        root.pendingExternalMonitor = ""
    }

    property Connections monitorConnections: Connections {
        target: Hyprland.monitors

        function onObjectInsertedPost(monitor, index) {
            if (monitor.name === root.internalMonitor) {
                // hyprmoncfg temporarily retargets workspaces when it is the
                // only active output. After the lid opens, keep them on the
                // external output instead of treating the laptop as a new
                // connection governed by Stay/Transfer.
                root.internalReturnTimer.restart()
                return
            }

            if (!root.ready)
                return

            root.pendingExternalMonitor = monitor.name

            root.hotplugRefreshTimer.restart()
        }

        function onObjectRemovedPre(monitor, index) {
            if (!root.ready || monitor.name === root.internalMonitor)
                return

            root.pendingRemovedWorkspaceIds = root.numberedWorkspaceIdsOn(monitor.name, 0)
            root.disconnectRefreshTimer.restart()
        }
    }

    property Timer startupTimer: Timer {
        interval: 1500
        repeat: false

        onTriggered: {
            root.ready = true

            if (root.externalMonitorCount > 0) {
                WallpaperService.reapply()

                if (root.transferOnConnect)
                    root.moveAllNumberedTo(root.preferredExternalMonitor())
                else
                    root.moveAllNumberedHome()
            } else if (!root.transferOnConnect) {
                root.moveAllNumberedHome()
            }
        }
    }

    property Timer hotplugRefreshTimer: Timer {
        interval: 1400
        repeat: false

        onTriggered: {
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()
            root.hotplugApplyTimer.restart()
        }
    }

    property Timer hotplugApplyTimer: Timer {
        interval: 200
        repeat: false

        onTriggered: root.settleAddedMonitor()
    }

    property Timer disconnectRefreshTimer: Timer {
        interval: 500
        repeat: false

        onTriggered: {
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()
            root.disconnectApplyTimer.restart()
        }
    }

    property Timer internalReturnTimer: Timer {
        interval: 1800
        repeat: false

        onTriggered: {
            Hyprland.refreshMonitors()
            Hyprland.refreshWorkspaces()

            const external = root.preferredExternalMonitor()

            if (external.length > 0)
                root.moveAllNumberedTo(external)
        }
    }

    property Timer disconnectApplyTimer: Timer {
        interval: 150
        repeat: false

        onTriggered: {
            root.moveIdsHome(root.pendingRemovedWorkspaceIds)
            root.pendingRemovedWorkspaceIds = []
        }
    }

    property IpcHandler ipc: IpcHandler {
        target: "display"

        function moveAll(direction: string): void {
            root.moveAllNumberedDirectional(direction)
        }

        function moveAllHome(): void {
            root.moveAllNumberedHome()
        }
    }

    Component.onCompleted: root.startupTimer.start()
}
