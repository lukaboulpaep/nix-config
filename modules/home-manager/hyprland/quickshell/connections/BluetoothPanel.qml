pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Bluetooth
import "ConnectionModel.js" as Model

Column {
    id: panel
    required property var service
    required property string fontFamily
    required property bool active
    property var selectedAdapter: null
    readonly property var adapter: service.adapters.includes(selectedAdapter) ? selectedAdapter : Bluetooth.defaultAdapter
    readonly property var savedDevices: adapter?.devices.values.filter(d => d.paired || d.connected) ?? []
    readonly property var nearbyDevices: adapter?.devices.values.filter(d => !d.paired && !d.connected) ?? []
    readonly property var namedDevices: nearbyDevices.filter(d => Model.bluetoothName(d).length > 0)
    readonly property var unidentifiedDevices: nearbyDevices.filter(d => !Model.bluetoothName(d))
    property bool devicesExpanded: false
    property bool nearbyExpanded: false
    property bool hasSearched: false
    property bool unidentifiedExpanded: false
    property var scanningAdapter: null
    property var powerAdapter: null
    property bool requestedPower: false
    property string powerError: ""
    signal resized
    spacing: 12
    function stopScan() {
        if (scanningAdapter)
            scanningAdapter.discovering = false;
        scanningAdapter = null;
        scanTimer.stop();
    }
    function scan() {
        if (!adapter?.enabled)
            return;
        stopScan();
        hasSearched = true;
        nearbyExpanded = true;
        devicesExpanded = true;
        scanningAdapter = adapter;
        adapter.discovering = true;
        scanTimer.restart();
    }
    onAdapterChanged: stopScan()
    onActiveChanged: if (!active) {
        stopScan();
        operation.cancel();
    }
    Component.onDestruction: stopScan()
    Timer {
        id: scanTimer
        interval: 30000
        onTriggered: panel.stopScan()
    }
    Timer {
        id: powerTimeout
        interval: 5000
        onTriggered: {
            if (panel.powerAdapter && panel.powerAdapter.enabled !== panel.requestedPower)
                panel.powerError = "Couldn’t change Bluetooth. Check your wireless switch and try again.";
            panel.powerAdapter = null;
        }
    }
    Connections {
        target: panel.powerAdapter
        function onEnabledChanged() {
            if (panel.powerAdapter?.enabled === panel.requestedPower) {
                powerTimeout.stop();
                panel.powerAdapter = null;
            }
        }
    }
    BluetoothOperation {
        id: operation
    }
    component Label: Text {
        textFormat: Text.PlainText
        color: "#B8B8B8"
        font {
            family: panel.fontFamily
            pixelSize: 12
        }
        wrapMode: Text.WordWrap
    }
    component NearbyDevice: Rectangle {
        id: device
        required property var modelData
        property bool unidentified: false
        width: panel.width
        height: nearbyRow.implicitHeight + 22
        radius: 9
        color: "#242424"
        Row {
            id: nearbyRow
            x: 11
            y: 11
            width: parent.width - 22
            spacing: 10
            Column {
                width: parent.width - pairButton.width - 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Label {
                    width: parent.width
                    text: Model.bluetoothLabel(device.modelData)
                    color: "#F8F9F9"
                    font.pixelSize: 13
                }
                Label {
                    visible: device.unidentified
                    text: device.modelData.address
                    font.pixelSize: 11
                }
            }
            ActionButton {
                id: pairButton
                anchors.verticalCenter: parent.verticalCenter
                text: "Pair"
                fontFamily: panel.fontFamily
                enabled: !operation.busy
                onClicked: {
                    panel.stopScan();
                    operation.run("pair", device.modelData);
                }
            }
        }
    }
    RadioHeader {
        width: parent.width
        title: "Bluetooth"
        icon: panel.adapter?.enabled ? "" : "󰂲"
        fontFamily: panel.fontFamily
        subtitle: !panel.adapter ? "No Bluetooth adapter detected" : panel.adapter.state === BluetoothAdapterState.Blocked ? "Disabled by the wireless switch" : !panel.adapter.enabled ? "Off" : panel.savedDevices.some(d => d.connected) ? panel.savedDevices.filter(d => d.connected).map(d => Model.bluetoothLabel(d)).join(", ") : "No devices connected"
        checked: panel.adapter?.enabled ?? false
        available: panel.adapter !== null && panel.adapter.state !== BluetoothAdapterState.Blocked && !operation.busy && !powerTimeout.running
        onToggled: {
            panel.powerError = "";
            panel.powerAdapter = panel.adapter;
            panel.requestedPower = !panel.adapter.enabled;
            if (!panel.requestedPower)
                panel.stopScan();
            powerTimeout.restart();
            panel.adapter.enabled = panel.requestedPower;
        }
    }
    Column {
        width: parent.width
        spacing: 7
        visible: panel.service.adapters.length > 1
        Label {
            text: "Bluetooth adapter"
        }
        Repeater {
            model: panel.service.adapters
            ActionButton {
                required property var modelData
                text: modelData.name + (panel.adapter === modelData ? " · Selected" : "")
                fontFamily: panel.fontFamily
                accent: panel.adapter === modelData
                onClicked: {
                    panel.stopScan();
                    panel.selectedAdapter = modelData;
                }
            }
        }
    }
    Label {
        width: parent.width
        visible: operation.error.length > 0
        text: operation.error
        color: "#EBA095"
    }
    Label {
        width: parent.width
        visible: panel.powerError.length > 0
        text: panel.powerError
        color: "#EBA095"
    }
    Column {
        width: parent.width
        spacing: 8
        visible: operation.busy
        Label {
            width: parent.width
            text: operation.deviceName + " · " + operation.progress
            color: "#D6B48C"
        }
        Rectangle {
            width: parent.width
            height: pairingContent.implicitHeight + 26
            visible: operation.prompt.length > 0
            radius: 11
            color: "#242424"
            border {
                width: 1
                color: "#655743"
            }
            Column {
                id: pairingContent
                x: 13
                y: 13
                width: parent.width - 26
                spacing: 10
                Label {
                    width: parent.width
                    color: "#F8F9F9"
                    text: operation.prompt === "confirm" ? "Does this code match the one on your device?" : operation.prompt === "display" ? "Enter this code on your device, then press Enter." : operation.prompt === "pin" || operation.prompt === "passkey" ? "Enter the pairing code shown on your device." : "Allow this device to pair?"
                }
                Label {
                    visible: operation.code.length > 0
                    text: operation.code
                    color: "#D6B48C"
                    font {
                        pixelSize: 28
                        letterSpacing: 4
                    }
                }
                TextField {
                    id: pairingCode
                    visible: ["pin", "passkey"].includes(operation.prompt)
                    width: parent.width
                    height: 38
                    color: "#F8F9F9"
                    font {
                        family: panel.fontFamily
                        pixelSize: 14
                    }
                    placeholderText: "Pairing code"
                    placeholderTextColor: "#888888"
                    maximumLength: operation.prompt === "passkey" ? 6 : 16
                    Accessible.name: "Bluetooth pairing code"
                    onVisibleChanged: {
                        clear();
                        if (visible)
                            forceActiveFocus();
                    }
                    background: Rectangle {
                        radius: 7
                        color: "#1D1D1D"
                        border {
                            width: 1
                            color: pairingCode.activeFocus ? "#D6B48C" : "#454545"
                        }
                    }
                    onAccepted: if (acceptPairing.enabled)
                        acceptPairing.clicked()
                }
                ActionButton {
                    id: acceptPairing
                    visible: operation.prompt !== "display"
                    text: operation.prompt === "confirm" ? "Codes match" : "Pair"
                    accent: true
                    fontFamily: panel.fontFamily
                    enabled: operation.prompt === "passkey" ? /^\d{1,6}$/.test(pairingCode.text) : operation.prompt === "pin" ? pairingCode.text.length > 0 : true
                    onClicked: {
                        operation.answer(pairingCode.text);
                        pairingCode.clear();
                    }
                }
            }
        }
        ActionButton {
            visible: operation.action === "pair"
            text: "Cancel pairing"
            fontFamily: panel.fontFamily
            onClicked: operation.cancel()
        }
    }
    Disclosure {
        width: parent.width
        text: "Devices"
        fontFamily: panel.fontFamily
        visible: panel.adapter !== null
        enabled: panel.adapter?.enabled ?? false
        checked: panel.devicesExpanded
        onClicked: {
            panel.devicesExpanded = checked;
            if (!checked)
                panel.stopScan();
            panel.resized();
        }
    }
    Column {
        width: parent.width
        spacing: 10
        visible: panel.devicesExpanded && (panel.adapter?.enabled ?? false)
        Label {
            width: parent.width
            visible: !panel.savedDevices.length
            text: "No saved devices yet. Put your device in pairing mode, then look for it below."
        }
        Repeater {
            model: panel.savedDevices
            Rectangle {
                id: deviceCard
                required property var modelData
                property bool expanded: false
                property bool confirmForget: false
                property bool editingName: false
                Connections {
                    target: operation
                    function onSucceeded(action, path) {
                        if (action === "rename" && path === deviceCard.modelData.dbusPath)
                            deviceCard.editingName = false;
                    }
                }
                width: panel.width
                height: deviceContent.implicitHeight + 24
                radius: 11
                color: "#242424"
                border {
                    width: 1
                    color: "#343434"
                }
                Column {
                    id: deviceContent
                    x: 12
                    y: 12
                    width: parent.width - 24
                    spacing: 9
                    Row {
                        width: parent.width
                        spacing: 10
                        Column {
                            width: parent.width - deviceAction.width - 10
                            spacing: 5
                            Label {
                                width: parent.width
                                text: Model.bluetoothLabel(deviceCard.modelData)
                                color: "#F8F9F9"
                                font {
                                    pixelSize: 13
                                    weight: Font.Medium
                                }
                            }
                            Label {
                                width: parent.width
                                text: (deviceCard.modelData.connected ? "Connected" : "Saved") + (deviceCard.modelData.batteryAvailable ? " · " + Math.round(deviceCard.modelData.battery * 100) + "% battery" : "")
                                color: deviceCard.modelData.connected ? "#A9C7BC" : "#B8B8B8"
                            }
                        }
                        ActionButton {
                            id: deviceAction
                            anchors.verticalCenter: parent.verticalCenter
                            text: deviceCard.modelData.connected ? "Disconnect" : "Connect"
                            fontFamily: panel.fontFamily
                            enabled: !operation.busy
                            onClicked: operation.run(deviceCard.modelData.connected ? "disconnect" : "connect", deviceCard.modelData)
                        }
                    }
                    Disclosure {
                        width: parent.width
                        text: "Device options"
                        fontFamily: panel.fontFamily
                        checked: deviceCard.expanded
                        onClicked: {
                            deviceCard.expanded = checked;
                            deviceCard.confirmForget = false;
                            panel.resized();
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: deviceCard.expanded
                        ActionButton {
                            text: "Rename"
                            fontFamily: panel.fontFamily
                            visible: !deviceCard.editingName
                            enabled: !operation.busy
                            onClicked: {
                                renameField.text = Model.bluetoothName(deviceCard.modelData);
                                deviceCard.editingName = true;
                                renameField.forceActiveFocus();
                                renameField.selectAll();
                            }
                        }
                        Column {
                            width: parent.width
                            spacing: 8
                            visible: deviceCard.editingName
                            Label {
                                text: "Name on this computer"
                                color: "#F8F9F9"
                            }
                            TextField {
                                id: renameField
                                objectName: "bluetoothDeviceName"
                                width: parent.width
                                height: 38
                                leftPadding: padding + 3
                                rightPadding: padding + 3
                                maximumLength: 128
                                selectByMouse: true
                                color: "#F8F9F9"
                                placeholderText: "Device name"
                                placeholderTextColor: "#888888"
                                font {
                                    family: panel.fontFamily
                                    pixelSize: 13
                                }
                                Accessible.name: "Bluetooth device name"
                                background: Rectangle {
                                    radius: 7
                                    color: "#1D1D1D"
                                    border {
                                        width: 1
                                        color: renameField.activeFocus ? "#D6B48C" : "#454545"
                                    }
                                }
                                onAccepted: if (saveName.enabled)
                                    saveName.clicked()
                            }
                            Row {
                                spacing: 8
                                ActionButton {
                                    id: saveName
                                    text: "Save name"
                                    accent: true
                                    fontFamily: panel.fontFamily
                                    enabled: !operation.busy && renameField.text.trim().length > 0 && !/[\x00-\x1f\x7f]/.test(renameField.text)
                                    onClicked: operation.run("rename", deviceCard.modelData, renameField.text.trim())
                                }
                                ActionButton {
                                    text: "Cancel"
                                    fontFamily: panel.fontFamily
                                    enabled: !operation.busy
                                    onClicked: {
                                        deviceCard.editingName = false;
                                        panel.resized();
                                    }
                                }
                            }
                            ActionButton {
                                text: "Use original name"
                                fontFamily: panel.fontFamily
                                enabled: !operation.busy
                                onClicked: operation.run("rename", deviceCard.modelData, "")
                            }
                        }
                        Label {
                            text: "Address  " + deviceCard.modelData.address
                        }
                        Label {
                            width: parent.width
                            text: "Allow automatic reconnection: " + (deviceCard.modelData.trusted ? "On" : "Off")
                        }
                        Row {
                            spacing: 8
                            ActionButton {
                                text: deviceCard.modelData.trusted ? "Turn off" : "Allow"
                                fontFamily: panel.fontFamily
                                enabled: !operation.busy
                                onClicked: operation.run(deviceCard.modelData.trusted ? "untrust" : "trust", deviceCard.modelData)
                            }
                            ActionButton {
                                text: deviceCard.confirmForget ? "Confirm forget" : "Forget device"
                                fontFamily: panel.fontFamily
                                enabled: !operation.busy
                                onClicked: {
                                    if (deviceCard.confirmForget)
                                        operation.run("forget", deviceCard.modelData);
                                    else
                                        deviceCard.confirmForget = true;
                                }
                            }
                        }
                        Label {
                            width: parent.width
                            visible: deviceCard.confirmForget
                            text: "You’ll need to pair this device again to reconnect."
                            color: "#D6B48C"
                        }
                    }
                }
            }
        }
        Row {
            spacing: 8
            ActionButton {
                objectName: "findBluetoothDevice"
                text: panel.scanningAdapter ? "Searching…" : "Find a device"
                fontFamily: panel.fontFamily
                accent: true
                enabled: !panel.scanningAdapter && !operation.busy
                onClicked: panel.scan()
            }
            ActionButton {
                text: "Stop"
                fontFamily: panel.fontFamily
                visible: panel.scanningAdapter !== null
                onClicked: panel.stopScan()
            }
        }
        Disclosure {
            objectName: "nearbyDevicesDisclosure"
            width: parent.width
            text: "Nearby devices"
            fontFamily: panel.fontFamily
            visible: panel.hasSearched
            checked: panel.nearbyExpanded
            onClicked: {
                panel.nearbyExpanded = checked;
                if (!checked)
                    panel.stopScan();
                panel.resized();
            }
        }
        Column {
            width: parent.width
            spacing: 8
            visible: panel.nearbyExpanded
            Label {
                width: parent.width
                visible: !panel.namedDevices.length
                text: panel.scanningAdapter ? "Looking for devices with names. Make sure your device is in pairing mode…" : "No named devices found. Put your device in pairing mode and search again."
            }
            Repeater {
                model: panel.namedDevices
                NearbyDevice {}
            }
            Disclosure {
                width: parent.width
                text: "Unidentified devices (" + panel.unidentifiedDevices.length + ")"
                fontFamily: panel.fontFamily
                visible: panel.unidentifiedDevices.length > 0
                checked: panel.unidentifiedExpanded
                onClicked: {
                    panel.unidentifiedExpanded = checked;
                    panel.resized();
                }
            }
            Column {
                width: parent.width
                spacing: 8
                visible: panel.unidentifiedExpanded && panel.unidentifiedDevices.length > 0
                Label {
                    width: parent.width
                    text: "These devices haven’t shared a name. Their Bluetooth addresses are shown below to help tell them apart."
                }
                Repeater {
                    model: panel.unidentifiedDevices
                    NearbyDevice {
                        unidentified: true
                    }
                }
            }
        }
    }
}
