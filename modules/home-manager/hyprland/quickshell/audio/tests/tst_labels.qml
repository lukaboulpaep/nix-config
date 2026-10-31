import QtQuick
import QtTest
import "../AudioModel.js" as Model

TestCase {
    name: "AudioOutputLabels"
    function card(id, props, kind) {
        return {
            id: id,
            type: "PipeWire:Interface:Device",
            info: {
                props: props,
                params: {
                    Route: [
                        {
                            direction: "Output",
                            device: 1,
                            available: "yes",
                            info: [1, "port.type", kind]
                        }
                    ],
                    EnumRoute: [
                        {
                            index: 1,
                            direction: "Output",
                            devices: [1],
                            profiles: [1],
                            available: "yes",
                            description: "Playback",
                            info: [1, "port.type", kind]
                        }
                    ],
                    EnumProfile: [
                        {
                            index: 1,
                            available: "yes",
                            priority: 1
                        }
                    ]
                }
            }
        };
    }
    function sink(id, name, description) {
        return {
            type: "PipeWire:Interface:Node",
            info: {
                props: {
                    "media.class": "Audio/Sink",
                    "device.id": id,
                    "card.profile.device": 1,
                    "node.name": name,
                    "node.description": description
                }
            }
        };
    }
    function test_bluetooth_speaker_keeps_device_name() {
        const snapshot = [card(1, {
                "device.api": "bluez5",
                "device.description": "Portable speaker"
            }, "speaker"), sink(1, "wireless", "Portable speaker"), card(2, {}, "speaker"), sink(2, "internal", "Internal audio")];
        const details = Model.outputDetails(snapshot);
        compare(details.wireless.name, "Portable speaker");
        compare(details.internal.name, "Speakers");
        compare(Model.friendlyName({
            name: "wireless"
        }, details, [
            {
                name: "wireless"
            },
            {
                name: "internal"
            }
        ]), "Portable speaker");
    }
    function test_bluetooth_alias_and_headphones() {
        const details = Model.outputDetails([card(1, {
                "device.api": "bluez5",
                "device.alias": "My headphones",
                "device.description": "Original product"
            }, "headphones"), sink(1, "headset", "Original product")]);
        compare(details.headset.name, "My headphones");
        compare(Model.bluetoothOutputName({
            "device.api": "bluez5",
            "node.description": "Wireless headset"
        }, {}), "Wireless headset");
    }
    function test_inactive_bluetooth_output_keeps_name() {
        compare(Model.inactiveOutputs([card(1, {
                "device.api": "bluez5",
                "device.description": "Portable speaker"
            }, "speaker")])[0].name, "Portable speaker");
    }
    function test_wired_routes_stay_simple() {
        const details = Model.outputDetails([card(1, {}, "headphones"), sink(1, "wired", "Driver name")]);
        compare(details.wired.name, "Headphones");
    }
    function test_live_bluetooth_alias_overrides_cached_audio_name() {
        const device = card(1, {
            "device.api": "bluez5",
            "api.bluez5.address": "aa:bb:cc:dd:ee:ff",
            "device.alias": "Old name"
        }, "speaker");
        const aliases = {
            "AA:BB:CC:DD:EE:FF": "Living room"
        };
        compare(Model.outputDetails([device, sink(1, "wireless", "Old name")], aliases).wireless.name, "Living room");
        compare(Model.inactiveOutputs([device], aliases)[0].name, "Living room");
        compare(Model.bluetoothOutputName({
            "node.name": "bluez_output.AA_BB_CC_DD_EE_FF.1"
        }, {}, aliases), "Living room");
        compare(Model.outputDetails([device, sink(1, "wireless", "Old name")]).wireless.name, "Old name");
    }
}
