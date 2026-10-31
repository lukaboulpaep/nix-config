pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

import ".." as BarComponents

PanelWindow {
    id: menu
    required property var theme
    property bool opened: false
    property int switchDirection: 0
    property alias switching: scene.switching
    property alias held: scene.held
    property var handoffFrom: null
    readonly property Item card: null
    property string page: ""
    property string action: ""
    property string errorMessage: ""
    property bool lockerAvailable: false
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
    // Gramercy is not distributed in Pond's repo. Use the system serif until
    // the user's chosen, licensed serif is supplied.
    readonly property string titleFontFamily: "serif"
    readonly property var actions: [
        {
            name: "Lock screen",
            action: "lock",
            icon: "lock",
            color: "#FFE51D",
            control: "#632B0F"
        },
        {
            name: "Sleep",
            action: "suspend",
            icon: "sleep",
            color: "#E99FFF",
            control: "#681D4F"
        },
        {
            name: "Restart",
            action: "reboot",
            icon: "restart",
            color: "#CEF058",
            control: "#1B322D"
        },
        {
            name: "Power off",
            action: "poweroff",
            icon: "power",
            color: "#FE6146",
            control: "#632B0F"
        }
    ]
    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }
    mask: BarComponents.BarMenuMask {
        menuWindow: menu
        barBottom: menu.theme.barMargin + menu.theme.barHeight
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-settings"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    visible: opened || scene.visible

    function openOn(targetScreen) {
        screen = targetScreen;
        page = "";
        action = "";
        errorMessage = "";
        opened = true;
    }
    function back() {
        if (page === "")
            opened = false;
        else {
            page = "";
            errorMessage = "";
        }
    }
    function requestAction(value) {
        if (sessionProcess.running)
            return;
        action = value;
        errorMessage = "";
        page = "session";
        if (value === "lock" && lockerAvailable)
            runAction();
    }
    function runAction() {
        if (sessionProcess.running)
            return;
        if (action === "lock") {
            if (!lockerAvailable)
                return;
            sessionProcess.command = ["hyprlock"];
        } else if (["suspend", "reboot", "poweroff"].includes(action)) {
            sessionProcess.command = ["systemctl", action];
        } else
            return;
        sessionProcess.running = true;
        opened = false;
    }
    onOpenedChanged: {
        if (opened) {
            scene.forceActiveFocus();
            if (!lockerCheck.running)
                lockerCheck.running = true;
        }
    }
    Process {
        id: lockerCheck
        command: ["sh", "-c", "command -v hyprlock >/dev/null && test -r /etc/pam.d/hyprlock && test -r \"${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprlock.conf\""]
        onExited: code => {
            menu.lockerAvailable = code === 0;
        }
    }
    Process {
        id: sessionProcess
        stderr: StdioCollector {
            id: sessionError
        }
        onExited: code => {
            if (code !== 0) {
                menu.errorMessage = sessionError.text.trim() || "The action could not be completed.";
                menu.page = "session";
                menu.opened = true;
            }
        }
    }
    PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }
    FileView {
        id: hostnameFile
        path: "/proc/sys/kernel/hostname"
        blockLoading: true
    }
    FileView {
        id: kernelFile
        path: "/proc/sys/kernel/osrelease"
        blockLoading: true
    }
    FileView {
        id: osFile
        path: "/etc/os-release"
        blockLoading: true
    }
    FileView {
        id: memoryFile
        path: "/proc/meminfo"
        blockLoading: true
    }

    BarComponents.BarMenuScene {
        id: scene
        opened: menu.opened
        Keys.onEscapePressed: menu.back()
        Rectangle {
            anchors.fill: parent
            color: "#101010"
            opacity: 0.7
        }
        MouseArea {
            anchors.fill: parent
            onClicked: menu.opened = false
        }

        Loader {
            id: content
            anchors.centerIn: parent
            active: menu.visible
            sourceComponent: ({
                    appearance: appearancePage,
                    bluetooth: bluetoothPage,
                    system: systemPage,
                    information: informationPage,
                    session: sessionPage
                })[menu.page] || homePage
            scale: Math.min(1, (menu.width - 48) / Math.max(1, width + (menu.page === "" ? 120 : 0)), (menu.height - 48) / Math.max(1, height))
        }
    }

    component BodyText: Text {
        color: "#B8B8B8"
        font {
            family: menu.theme.fontFamily
            pixelSize: 13
        }
        wrapMode: Text.WordWrap
    }
    component Page: PageFrame {
        fontFamily: menu.theme.fontFamily
        titleFontFamily: menu.titleFontFamily
        onBack: menu.back()
    }
    component ActionButton: SettingsButton {
        fontFamily: menu.theme.fontFamily
    }

    Component {
        id: homePage
        Item {
            implicitWidth: 422
            implicitHeight: 336
            Repeater {
                model: [
                    {
                        label: "Appearance",
                        page: "appearance"
                    },
                    {
                        label: "Bluetooth",
                        page: "bluetooth"
                    },
                    {
                        label: "System",
                        page: "system"
                    },
                    {
                        label: "Information",
                        page: "information"
                    }
                ]
                MenuTile {
                    required property var modelData
                    required property int index
                    x: (index % 2) * 172
                    y: Math.floor(index / 2) * 172
                    width: 164
                    height: 164
                    text: modelData.label
                    iconSource: "icons/" + modelData.page + ".svg"
                    titleFontFamily: menu.titleFontFamily
                    revealDelay: index * 28
                    onClicked: menu.page = modelData.page
                }
            }
            Repeater {
                model: menu.actions
                MenuTile {
                    required property var modelData
                    required property int index
                    x: 344
                    y: index * 86
                    width: 78
                    height: 78
                    sessionAction: true
                    text: modelData.name
                    iconSource: "icons/" + modelData.icon + ".svg"
                    titleFontFamily: menu.titleFontFamily
                    hoverColor: modelData.color
                    controlColor: modelData.control
                    revealDelay: (index + 4) * 28
                    onClicked: menu.requestAction(modelData.action)
                }
            }
        }
    }

    Component {
        id: appearancePage
        Page {
            title: "Appearance"
            implicitWidth: 640
            BodyText {
                width: parent.width
                text: "Choose your theme and wallpaper. Each design has a light and dark version."
            }
            Row {
                id: themeChoices
                width: parent.width
                spacing: 12
                Repeater {
                    model: ["light", "dark"]
                    WallpaperCard {
                        id: themeChoice
                        required property string modelData
                        width: (themeChoices.width - themeChoices.spacing) / 2
                        height: 130
                        fontFamily: menu.theme.fontFamily
                        label: modelData === "light" ? "Light" : "Dark"
                        selected: menu.theme.mode === modelData
                        previewSource: menu.theme.wallpaperUrl(menu.theme.wallpaperId, modelData)
                        Accessible.name: "Use " + modelData + " theme"
                        Accessible.description: "Change desktop color theme"
                        onClicked: menu.theme.apply(modelData)
                    }
                }
            }
            BodyText {
                text: "Wallpaper"
                color: "#F8F9F9"
            }
            Grid {
                id: wallpaperChoices
                width: parent.width
                columns: 3
                spacing: 12
                Repeater {
                    model: menu.theme.wallpapers
                    WallpaperCard {
                        required property var modelData
                        width: (wallpaperChoices.width - 2 * wallpaperChoices.spacing) / 3
                        fontFamily: menu.theme.fontFamily
                        label: modelData.name
                        selected: menu.theme.wallpaperId === modelData.id
                        previewSource: menu.theme.wallpaperUrl(modelData.id, menu.theme.mode)
                        enabled: !menu.theme.wallpaperSaving
                        onClicked: menu.theme.selectWallpaper(modelData.id)
                    }
                }
            }
            BodyText {
                width: parent.width
                visible: menu.theme.wallpaperError.length > 0
                text: menu.theme.wallpaperError
                color: "#EBA095"
            }
        }
    }

    Component {
        id: bluetoothPage
        Page {
            title: "Bluetooth"
            Row {
                spacing: 12
                ActionButton {
                    text: menu.adapter?.enabled ? "Turn off" : "Turn on"
                    enabled: menu.adapter !== null
                    onClicked: menu.adapter.enabled = !menu.adapter.enabled
                }
                ActionButton {
                    text: "Pair a device…"
                    enabled: menu.adapter?.enabled ?? false
                    onClicked: {
                        Quickshell.execDetached(["blueman-manager"]);
                        menu.opened = false;
                    }
                }
            }
            BodyText {
                width: parent.width
                text: !menu.adapter ? "No Bluetooth adapter is available." : !menu.adapter.enabled ? "Bluetooth is off." : "Connect a saved device, or pair a new one."
            }
            Flickable {
                width: parent.width
                height: Math.min(224, deviceList.implicitHeight)
                contentHeight: deviceList.implicitHeight
                clip: true
                Column {
                    id: deviceList
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: menu.adapter?.devices.values.filter(device => device.paired) ?? []
                        ActionButton {
                            required property var modelData
                            width: deviceList.width
                            text: modelData.name + "  ·  " + (modelData.connected ? "Disconnect" : "Connect")
                            enabled: menu.adapter?.enabled ?? false
                            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: systemPage
        Page {
            title: "System"
            BodyText {
                text: "Sound"
                color: "#F8F9F9"
            }
            Row {
                spacing: 12
                ActionButton {
                    width: 90
                    text: menu.audio?.muted ? "Unmute" : "Mute"
                    enabled: menu.audio !== null
                    onClicked: menu.audio.muted = !menu.audio.muted
                }
                Slider {
                    id: volume
                    width: 220
                    height: 38
                    from: 0
                    to: 1
                    value: menu.audio?.volume ?? 0
                    enabled: menu.audio !== null
                    Accessible.name: "Output volume"
                    onMoved: menu.audio.volume = value
                    background: Rectangle {
                        x: volume.leftPadding
                        y: (volume.height - height) / 2
                        width: volume.availableWidth
                        height: 5
                        radius: 3
                        color: "#383838"
                        Rectangle {
                            width: parent.width * volume.visualPosition
                            height: parent.height
                            radius: 3
                            color: "#D6B48C"
                        }
                    }
                    handle: Rectangle {
                        x: volume.leftPadding + volume.visualPosition * (volume.availableWidth - width)
                        y: (volume.height - height) / 2
                        width: 14
                        height: 14
                        radius: 7
                        color: volume.pressed || volume.visualFocus ? "#D6B48C" : "#F8F9F9"
                    }
                }
                BodyText {
                    y: 11
                    text: menu.audio ? Math.round(menu.audio.volume * 100) + "%" : "—"
                }
            }
            BodyText {
                width: parent.width
                text: Pipewire.defaultAudioSink?.description ?? "No audio output is available."
            }
            Rectangle {
                width: parent.width
                height: 1
                color: "#303030"
            }
            BodyText {
                text: "Power"
                color: "#F8F9F9"
            }
            BodyText {
                width: parent.width
                text: UPower.displayDevice.ready && UPower.displayDevice.isPresent ? Math.round(UPower.displayDevice.percentage * 100) + "% · " + (UPower.onBattery ? "On battery" : "Plugged in") : "Connected to power"
            }
        }
    }

    Component {
        id: informationPage
        Page {
            title: "Information"
            Repeater {
                model: [["Computer", hostnameFile.text().trim()], ["Operating system", (osFile.text().split("\n").find(line => line.startsWith("PRETTY_NAME=")) || "PRETTY_NAME=Linux").slice(12).replace(/^"|"$/g, "")], ["Kernel", kernelFile.text().trim()], ["Memory", Math.round(Number((memoryFile.text().match(/MemTotal:\s+(\d+)/) || [0, 0])[1]) / 1048576) + " GiB"], ["Display", menu.screen ? menu.screen.name + " · " + menu.screen.width + " × " + menu.screen.height + " logical pixels" : "—"]]
                Column {
                    id: infoRow
                    required property var modelData
                    width: parent.width
                    spacing: 5
                    BodyText {
                        text: infoRow.modelData[0]
                    }
                    BodyText {
                        width: parent.width
                        text: infoRow.modelData[1]
                        color: "#F8F9F9"
                    }
                }
            }
        }
    }

    Component {
        id: sessionPage
        Page {
            id: sessionPanel
            readonly property var selected: menu.actions.find(item => item.action === menu.action)
            title: selected?.name ?? "Session"
            BodyText {
                width: parent.width
                text: menu.errorMessage || (menu.action === "lock" && !menu.lockerAvailable ? "Screen locking is not available yet." : menu.action === "suspend" ? "Put this computer to sleep?" : "Save your work before continuing.")
            }
            Row {
                spacing: 10
                ActionButton {
                    text: "Cancel"
                    onClicked: menu.back()
                }
                ActionButton {
                    text: sessionPanel.selected?.name ?? "Continue"
                    fillColor: sessionPanel.selected?.color ?? "#383838"
                    textColor: "#1D1D1D"
                    enabled: !sessionProcess.running && (menu.action !== "lock" || menu.lockerAvailable)
                    onClicked: menu.runAction()
                }
            }
        }
    }
}
