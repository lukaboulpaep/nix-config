import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import "ConnectionModel.js" as Model

Scope {
    id: service
    property bool active: false
    property bool wifiExpanded: false
    readonly property var wifiDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wifi)
    readonly property var networks: Model.networks(wifiDevices)
    readonly property var currentWifi: networks.find(n => n.connected) ?? null
    readonly property var ethernet: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property bool available: Networking.backend !== NetworkBackendType.None
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiBlocked: !Networking.wifiHardwareEnabled
    readonly property var adapters: Bluetooth.adapters.values
    readonly property bool bluetoothPowered: adapters.some(a => a.enabled)
    readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.connected)
    property var wifiTarget: null
    property var passwordNetwork: null
    property string wifiError: ""
    property bool connecting: false
    readonly property bool wifiBusy: connecting || radio.running || disconnect.running
    readonly property string networkName: currentWifi?.name ?? (ethernet ? "Ethernet" : wifiEnabled ? "Not connected" : "Wi-Fi off")
    readonly property string networkType: currentWifi ? "wifi" : ethernet ? "ethernet" : ""
    readonly property string connectivityText: Networking.connectivity === NetworkConnectivity.Portal ? "Sign-in may be needed" : Networking.connectivity === NetworkConnectivity.Limited ? "Limited internet access" : currentWifi || ethernet ? "Connected" : "Not connected"
    function needsPassword(network) {
        return [WifiSecurityType.WpaPsk, WifiSecurityType.Wpa2Psk, WifiSecurityType.Sae].includes(network.security);
    }
    function connectNetwork(network) {
        if (!network || wifiBusy || network.connected)
            return;
        wifiError = "";
        if (!network.known && needsPassword(network)) {
            passwordNetwork = network;
            return;
        }
        if (!network.known && ![WifiSecurityType.Open, WifiSecurityType.Owe].includes(network.security)) {
            wifiError = "This network needs additional settings that aren’t available here yet.";
            return;
        }
        startConnection(network, "", false);
    }
    function startConnection(network, password, withPassword) {
        if (!network || wifiBusy)
            return;
        wifiTarget = network;
        wifiError = "";
        connecting = true;
        connectionTimeout.restart();
        passwordNetwork = null;
        if (withPassword)
            network.connectWithPsk(password);
        else
            network.connect();
    }
    function disconnectWifi(network) {
        if (!network || wifiBusy)
            return;
        wifiError = "";
        disconnect.command = ["nmcli", "--wait", "15", "device", "disconnect", network.device.name];
        disconnect.running = true;
    }
    function toggleWifi() {
        if (wifiBusy || wifiBlocked)
            return;
        wifiError = "";
        passwordNetwork = null;
        radio.command = ["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"];
        radio.running = true;
    }
    onActiveChanged: if (!active)
        passwordNetwork = null
    Process {
        id: radio
        onExited: code => {
            if (code !== 0)
                service.wifiError = "Couldn’t change Wi-Fi. Check your wireless switch or try again.";
        }
    }
    Process {
        id: disconnect
        onExited: code => {
            if (code !== 0)
                service.wifiError = "Couldn’t disconnect from this network. Try again.";
        }
    }
    Connections {
        target: service.wifiTarget
        function onConnectedChanged() {
            if (service.wifiTarget?.connected) {
                service.connecting = false;
                connectionTimeout.stop();
                service.wifiError = "";
                service.passwordNetwork = null;
            }
        }
        function onConnectionFailed(reason) {
            service.connecting = false;
            connectionTimeout.stop();
            if (reason === ConnectionFailReason.NoSecrets && service.wifiTarget && service.needsPassword(service.wifiTarget)) {
                service.wifiError = "Check the Wi-Fi password and try again.";
                if (service.active)
                    service.passwordNetwork = service.wifiTarget;
            } else
                service.wifiError = "Couldn’t connect. Check the signal and try again.";
        }
    }
    Timer {
        id: connectionTimeout
        interval: 45000
        onTriggered: {
            service.connecting = false;
            service.wifiError = "Connecting is taking longer than expected. Check the network and try again.";
        }
    }
    Instantiator {
        model: service.wifiDevices
        delegate: Binding {
            required property var modelData
            target: modelData
            property: "scannerEnabled"
            value: service.active && service.wifiExpanded && service.wifiEnabled
        }
    }
}
