import QtQuick
import QtTest
import "../ConnectionModel.js" as Model

TestCase {
    name: "ConnectionsModel"
    function network(name, security, signal, connected = false, known = false) {
        return {
            name: name,
            security: security,
            signalStrength: signal,
            connected: connected,
            known: known,
            stateChanging: false
        };
    }
    function test_duplicate_networks_prefer_active_connection() {
        const active = network("Home", 3, 0.3, true, true);
        const networks = Model.networks([
            {
                networks: {
                    values: [network("Home", 3, 0.9), active, network("Home", 10, 0.8), network("", 3, 0.5)]
                }
            }
        ]);
        compare(networks.length, 2);
        compare(networks[0], active);
        compare(networks[1].security, 10);
    }
    function test_multiple_adapters_and_order() {
        const result = Model.networks([
            {
                networks: {
                    values: [network("Cafe", 3, 0.2), network("Saved", 3, 0.2, false, true)]
                }
            },
            {
                networks: {
                    values: [network("Cafe", 3, 0.8), network("Nearby", 3, 0.9)]
                }
            }
        ]);
        compare(result.length, 3);
        compare(result[0].name, "Saved");
        compare(result[1].name, "Nearby");
        compare(result[2].signalStrength, 0.8);
    }
    function test_password_validation() {
        verify(!Model.passwordValid("short", false));
        verify(Model.passwordValid("test passphrase", false));
        verify(Model.passwordValid("a".repeat(64), false));
        verify(!Model.passwordValid("z".repeat(64), false));
        verify(Model.passwordValid("a", true));
        verify(!Model.passwordValid("", true));
        verify(!Model.passwordValid("a".repeat(64), true));
    }
    function test_bluetooth_addresses_are_not_device_names() {
        compare(Model.bluetoothName({
            name: "4B-18-63-1B-3B-7A"
        }), "");
        compare(Model.bluetoothName({
            name: "4b:18:63:1b:3b:7a"
        }), "");
        compare(Model.bluetoothName({
            name: "4B18631B3B7A"
        }), "");
        compare(Model.bluetoothName({
            name: "4B-18-63-1B-3B-7A",
            deviceName: "Living room speaker"
        }), "Living room speaker");
        compare(Model.bluetoothName({
            name: "My headphones",
            deviceName: "Headset"
        }), "My headphones");
        compare(Model.bluetoothLabel({
            name: "",
            icon: "audio-headset"
        }), "Unnamed headset");
        compare(Model.bluetoothLabel({
            name: "",
            icon: ""
        }), "Unnamed device");
    }
}
