import QtQuick
import Quickshell
import "system" as System

Scope {
    id: metrics
    required property var connections
    property alias cpu: systemMetrics.cpu
    property alias memory: systemMetrics.memory
    property alias system: systemMetrics
    property bool systemActive: false
    readonly property string networkName: connections.networkName
    readonly property string networkType: connections.networkType
    readonly property bool networkReady: connections.available
    readonly property bool bluetoothAvailable: connections.adapters.length > 0
    readonly property bool bluetoothPowered: connections.bluetoothPowered
    System.SystemMetrics {
        id: systemMetrics
        active: metrics.systemActive
    }
}
