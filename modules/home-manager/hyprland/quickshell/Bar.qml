import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

PanelWindow {
    id: bar
    signal settingsRequested
    signal displaysRequested
    property bool displaysOpened: false
    signal audioRequested
    property bool audioOpened: false
    signal brightnessRequested
    property bool brightnessOpened: false
    property int displayBrightness: -1
    signal systemRequested
    property bool systemOpened: false
    signal connectionsRequested
    property bool connectionsOpened: false
    signal batteryRequested
    property bool batteryOpened: false
    required property var metrics
    required property var workspaceEntries
    property url wallpaperSource: ""

    required property color backgroundColor
    property real backgroundOpacity: 0.64
    required property color textColor
    required property int edgeMargin
    required property int cornerRadius
    required property string fontFamily
    required property int fontSize
    required property int surfaceHeight
    readonly property int shadowPadding: 8

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery.ready && battery.isPresent && battery.isLaptopBattery
    readonly property int batteryPercent: Math.round(battery.percentage * 100)
    // HyperFlow's vertical battery levels and plugged-in glyph.
    // https://github.com/Baran-sys/HyperFlow-dotfiles/blob/main/.config/waybar/config.jsonc
    readonly property var batteryIcons: ["󰂃", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    readonly property string batteryIcon: !UPower.onBattery ? "" : batteryIcons[Math.max(0, Math.min(10, Math.floor(batteryPercent / 10)))]
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property var audio: audioSink?.audio ?? null
    readonly property int volume: audio ? Math.round(audio.volume * 100) : 0

    PwObjectTracker {
        objects: bar.audioSink ? [bar.audioSink] : []
    }
    function menuAnchorCenter(name) {
        const group = ({
                audio: audioGroup,
                brightness: brightnessGroup,
                system: systemGroup,
                battery: batteryGroup,
                connections: connectionGroup
            })[name];
        if (!group || !group.visible)
            return width + margins.left - edgeMargin;
        return margins.left + surface.x + status.x + group.x + group.width / 2;
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component Indicator: BarIndicator {
        foreground: bar.textColor
        fontFamily: bar.fontFamily
        fontSize: bar.fontSize
    }

    component Group: BarGroup {
        backgroundColor: bar.backgroundColor
        backgroundOpacity: bar.backgroundOpacity
        cornerRadius: bar.cornerRadius
        surfaceHeight: bar.surfaceHeight
    }

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Math.max(0, bar.edgeMargin - bar.shadowPadding)
        left: Math.max(0, bar.edgeMargin - bar.shadowPadding)
        right: Math.max(0, bar.edgeMargin - bar.shadowPadding)
    }
    implicitHeight: surfaceHeight + 2 * shadowPadding
    // Reserve the visible bar and top inset, not the shadow below it.
    exclusiveZone: surfaceHeight + shadowPadding
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-bar"
    color: "transparent"
    // Only the pills receive input; the gaps pass clicks through to the desktop.
    mask: Region {
        Region {
            item: settingsGroup
            radius: bar.cornerRadius
        }
        Region {
            item: monitorsGroup.visible ? monitorsGroup : null
            radius: bar.cornerRadius
        }
        Region {
            item: clockGroup.visible ? clockGroup : null
            radius: bar.cornerRadius
        }
        Region {
            item: workspaceGroup
            radius: bar.cornerRadius
        }
        Region {
            item: connectionGroup.visible ? connectionGroup : null
            radius: bar.cornerRadius
        }
        Region {
            item: batteryGroup.visible ? batteryGroup : null
            radius: bar.cornerRadius
        }
        Region {
            item: systemGroup.visible ? systemGroup : null
            radius: bar.cornerRadius
        }
        Region {
            item: brightnessGroup.visible ? brightnessGroup : null
            radius: bar.cornerRadius
        }
        Region {
            item: audioGroup.visible ? audioGroup : null
            radius: bar.cornerRadius
        }
    }

    Item {
        id: surface
        anchors.fill: parent
        anchors.margins: bar.shadowPadding

        Row {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            spacing: 6

            Group {
                id: settingsGroup
                horizontalPadding: 0

                Button {
                    id: settingsButton
                    width: 40
                    height: bar.surfaceHeight
                    padding: (height - 14) / 2
                    leftPadding: 11
                    rightPadding: 11
                    hoverEnabled: true
                    Accessible.name: "Open settings"
                    background: Rectangle {
                        radius: bar.cornerRadius
                        antialiasing: true
                        color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, settingsButton.down ? 0.16 : settingsButton.hovered ? 0.08 : 0)
                        border.width: settingsButton.visualFocus ? 1 : 0
                        border.color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, 0.5)
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    contentItem: Image {
                        source: "settings/icons/system.svg"
                        sourceSize: Qt.size(32, 32)
                        fillMode: Image.PreserveAspectFit
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    onClicked: bar.settingsRequested()
                }
            }

            Group {
                id: monitorsGroup
                horizontalPadding: 0
                Button {
                    id: displaysButton
                    width: 36
                    height: bar.surfaceHeight
                    padding: 8
                    hoverEnabled: true
                    Accessible.name: "Open display layouts"
                    background: Rectangle {
                        radius: bar.cornerRadius
                        antialiasing: true
                        color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, displaysButton.down ? 0.16 : bar.displaysOpened ? 0.12 : displaysButton.hovered ? 0.08 : 0)
                        border.width: displaysButton.visualFocus ? 1 : 0
                        border.color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, 0.5)
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    contentItem: Item {
                        Shape {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            antialiasing: true
                            ShapePath {
                                strokeColor: bar.textColor
                                strokeWidth: 1.4
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                startX: 1
                                startY: 2
                                PathLine {
                                    x: 15
                                    y: 2
                                }
                                PathLine {
                                    x: 15
                                    y: 11
                                }
                                PathLine {
                                    x: 1
                                    y: 11
                                }
                                PathLine {
                                    x: 1
                                    y: 2
                                }
                                PathMove {
                                    x: 8
                                    y: 11
                                }
                                PathLine {
                                    x: 8
                                    y: 14
                                }
                                PathMove {
                                    x: 5
                                    y: 14
                                }
                                PathLine {
                                    x: 11
                                    y: 14
                                }
                            }
                        }
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    onClicked: bar.displaysRequested()
                }
            }

            Group {
                id: clockGroup
                visible: width + settingsGroup.width + workspaceGroup.width + (monitorsGroup.visible ? monitorsGroup.width + 6 : 0) + status.width + 24 < surface.width

                Indicator {
                    icon: ""
                    label: Qt.formatDateTime(clock.date, "dd-MM-yyyy")
                    description: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                }
                Indicator {
                    icon: ""
                    label: Qt.formatDateTime(clock.date, "HH:mm")
                    description: "Time: " + label
                }
            }

            Group {
                id: workspaceGroup
                horizontalPadding: 6

                BarWorkspaces {
                    monitorName: bar.screen?.name || ""
                    entries: bar.workspaceEntries
                    wallpaperSource: bar.wallpaperSource
                    foreground: bar.textColor
                    fontFamily: bar.fontFamily
                    fontSize: bar.fontSize
                }
            }
        }

        Row {
            id: status
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 6

            Group {
                id: connectionGroup
                visible: (metrics.networkReady || metrics.bluetoothAvailable) && surface.width > 550
                horizontalPadding: 0
                Button {
                    id: connectionButton
                    implicitWidth: connectionIndicators.implicitWidth + 20
                    height: bar.surfaceHeight
                    horizontalPadding: 10
                    verticalPadding: 2
                    hoverEnabled: true
                    Accessible.name: "Open Wi-Fi and Bluetooth"
                    Accessible.description: bar.metrics.networkName
                    background: Rectangle {
                        radius: bar.cornerRadius
                        antialiasing: true
                        color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, connectionButton.down ? 0.16 : bar.connectionsOpened ? 0.12 : connectionButton.hovered ? 0.08 : 0)
                        border.width: connectionButton.visualFocus ? 1 : 0
                        border.color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, 0.5)
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    contentItem: Row {
                        id: connectionIndicators
                        spacing: 14
                        Indicator {
                            visible: bar.metrics.networkReady
                            icon: bar.metrics.networkType === "wifi" ? "󰤨" : bar.metrics.networkType === "ethernet" ? "󰈀" : "󰖪"
                            label: surface.width > 750 ? bar.metrics.networkName : ""
                            description: bar.metrics.networkName
                        }
                        Indicator {
                            visible: bar.metrics.bluetoothAvailable
                            icon: bar.metrics.bluetoothPowered ? "" : "󰂲"
                            description: bar.metrics.bluetoothPowered ? "Bluetooth on" : "Bluetooth off"
                        }
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    onClicked: bar.connectionsRequested()
                }
            }

            Group {
                id: batteryGroup
                visible: bar.hasBattery
                horizontalPadding: 0
                Button {
                    id: batteryButton
                    implicitWidth: batteryIndicator.implicitWidth + 20
                    height: bar.surfaceHeight
                    horizontalPadding: 10
                    verticalPadding: 2
                    hoverEnabled: true
                    Accessible.name: "Open battery and power modes"
                    Accessible.description: "Battery " + bar.batteryPercent + " percent"
                    background: Rectangle {
                        radius: bar.cornerRadius
                        antialiasing: true
                        color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, batteryButton.down ? 0.16 : bar.batteryOpened ? 0.12 : batteryButton.hovered ? 0.08 : 0)
                        border.width: batteryButton.visualFocus ? 1 : 0
                        border.color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, 0.5)
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    contentItem: Indicator {
                        id: batteryIndicator
                        icon: bar.batteryIcon
                        label: bar.batteryPercent + "%"
                        description: UPowerDeviceState.toString(bar.battery.state) + " · " + label
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    onClicked: bar.batteryRequested()
                }
            }

            Group {
                id: systemGroup
                visible: surface.width > 750 && (metrics.cpu >= 0 || metrics.memory >= 0)
                horizontalPadding: 0
                Button {
                    id: systemButton
                    implicitWidth: systemIndicators.implicitWidth + 20
                    height: bar.surfaceHeight
                    horizontalPadding: 10
                    verticalPadding: 2
                    hoverEnabled: true
                    Accessible.name: "Open system monitor"
                    Accessible.description: "CPU " + bar.metrics.cpu + " percent, RAM " + bar.metrics.memory + " percent"
                    background: Rectangle {
                        radius: bar.cornerRadius
                        antialiasing: true
                        color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, systemButton.down ? 0.16 : bar.systemOpened ? 0.12 : systemButton.hovered ? 0.08 : 0)
                        border.width: systemButton.visualFocus ? 1 : 0
                        border.color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, 0.5)
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    contentItem: Row {
                        id: systemIndicators
                        spacing: 14
                        Indicator {
                            visible: bar.metrics.cpu >= 0
                            icon: ""
                            label: bar.metrics.cpu + "%"
                            description: "CPU usage: " + label
                        }
                        Indicator {
                            visible: bar.metrics.memory >= 0
                            icon: "󰘚"
                            label: bar.metrics.memory + "%"
                            description: "Memory usage: " + label
                        }
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    onClicked: bar.systemRequested()
                }
            }

            Group {
                id: brightnessGroup
                horizontalPadding: 0

                Button {
                    id: brightnessButton
                    implicitWidth: brightnessIndicator.implicitWidth + 20
                    height: bar.surfaceHeight
                    horizontalPadding: 10
                    verticalPadding: 2
                    hoverEnabled: true
                    Accessible.name: "Open brightness controls"
                    background: Rectangle {
                        radius: bar.cornerRadius
                        antialiasing: true
                        color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, brightnessButton.down ? 0.16 : bar.brightnessOpened ? 0.12 : brightnessButton.hovered ? 0.08 : 0)
                        border.width: brightnessButton.visualFocus ? 1 : 0
                        border.color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, 0.5)
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    contentItem: Indicator {
                        id: brightnessIndicator
                        icon: bar.displayBrightness < 34 ? "󰃞" : bar.displayBrightness < 67 ? "󰃟" : "󰃠"
                        label: bar.displayBrightness >= 0 ? bar.displayBrightness + "%" : ""
                        description: "Display brightness"
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    onClicked: bar.brightnessRequested()
                }
            }

            Group {
                id: audioGroup
                horizontalPadding: 0

                Button {
                    id: audioButton
                    implicitWidth: audioIndicator.implicitWidth + 20
                    height: bar.surfaceHeight
                    horizontalPadding: 10
                    verticalPadding: 2
                    hoverEnabled: true
                    Accessible.name: "Open sound controls"
                    Accessible.description: audioIndicator.description
                    background: Rectangle {
                        radius: bar.cornerRadius
                        antialiasing: true
                        color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, audioButton.down ? 0.16 : bar.audioOpened ? 0.12 : audioButton.hovered ? 0.08 : 0)
                        border.width: audioButton.visualFocus ? 1 : 0
                        border.color: Qt.rgba(bar.textColor.r, bar.textColor.g, bar.textColor.b, 0.5)
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }
                    contentItem: Indicator {
                        id: audioIndicator
                        icon: !bar.audio || bar.audio.muted ? "" : bar.volume === 0 ? "" : bar.volume < 67 ? "" : ""
                        label: !bar.audio ? "—" : bar.audio.muted ? "Muted" : bar.volume + "%"
                        description: (bar.audioSink?.description ?? "No audio output") + " · " + label
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    onClicked: bar.audioRequested()
                }
            }
        }
    }
}
