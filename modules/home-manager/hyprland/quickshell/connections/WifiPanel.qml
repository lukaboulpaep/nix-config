pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Networking
import "ConnectionModel.js" as Model

Column {
    id: panel
    required property var service
    required property string fontFamily
    signal resized
    spacing: 12
    component Label: Text {
        textFormat: Text.PlainText
        color: "#B8B8B8"
        font {
            family: panel.fontFamily
            pixelSize: 12
        }
        wrapMode: Text.WordWrap
    }
    RadioHeader {
        width: parent.width
        title: "Wi-Fi"
        fontFamily: panel.fontFamily
        icon: panel.service.wifiEnabled ? "󰤨" : "󰤭"
        subtitle: !panel.service.available ? "Network service unavailable" : !panel.service.wifiDevices.length ? "No Wi-Fi adapter detected" : panel.service.wifiBlocked ? "Disabled by the wireless switch" : !panel.service.wifiEnabled ? "Off" : panel.service.currentWifi ? panel.service.connectivityText : "Not connected"
        checked: panel.service.wifiEnabled
        available: panel.service.available && panel.service.wifiDevices.length > 0 && !panel.service.wifiBlocked && !panel.service.wifiBusy
        onToggled: panel.service.toggleWifi()
    }
    Rectangle {
        width: parent.width
        height: currentContent.implicitHeight + 26
        radius: 11
        color: "#242424"
        border {
            width: 1
            color: "#3D443F"
        }
        visible: panel.service.currentWifi !== null
        Row {
            id: currentContent
            x: 13
            y: 13
            width: parent.width - 26
            spacing: 10
            Column {
                width: parent.width - disconnect.width - 10
                spacing: 5
                Label {
                    width: parent.width
                    text: panel.service.currentWifi?.name ?? ""
                    color: "#F8F9F9"
                    font {
                        pixelSize: 13
                        weight: Font.Medium
                    }
                }
                Label {
                    text: Model.strength(panel.service.currentWifi?.signalStrength ?? 0)
                    color: "#A9C7BC"
                }
            }
            ActionButton {
                id: disconnect
                anchors.verticalCenter: parent.verticalCenter
                text: "Disconnect"
                fontFamily: panel.fontFamily
                enabled: !panel.service.wifiBusy
                onClicked: panel.service.disconnectWifi(panel.service.currentWifi)
            }
        }
    }
    Label {
        width: parent.width
        visible: panel.service.ethernet !== null
        text: "󰈀  Ethernet is connected"
        color: "#A9C7BC"
    }
    Label {
        width: parent.width
        visible: panel.service.wifiError.length > 0
        text: panel.service.wifiError
        color: "#EBA095"
    }
    Label {
        width: parent.width
        visible: panel.service.connecting
        text: "Connecting to " + (panel.service.wifiTarget?.name ?? "network") + "…"
        color: "#D6B48C"
    }
    Rectangle {
        id: passwordCard
        width: parent.width
        height: passwordContent.implicitHeight + 26
        visible: panel.service.passwordNetwork !== null
        radius: 11
        color: "#242424"
        border {
            width: 1
            color: "#655743"
        }
        onVisibleChanged: {
            password.clear();
            if (visible)
                password.forceActiveFocus();
        }
        Column {
            id: passwordContent
            x: 13
            y: 13
            width: parent.width - 26
            spacing: 10
            Label {
                width: parent.width
                text: "Join " + (panel.service.passwordNetwork?.name ?? "network")
                color: "#F8F9F9"
                font {
                    pixelSize: 13
                    weight: Font.Medium
                }
            }
            TextField {
                id: password
                objectName: "wifiPassword"
                width: parent.width
                height: 38
                leftPadding: padding + 3
                rightPadding: padding + 3
                placeholderText: "Wi-Fi password"
                placeholderTextColor: "#888888"
                color: "#F8F9F9"
                echoMode: TextInput.Password
                selectByMouse: true
                font {
                    family: panel.fontFamily
                    pixelSize: 13
                }
                Accessible.name: "Wi-Fi password"
                background: Rectangle {
                    radius: 7
                    color: "#1D1D1D"
                    border {
                        width: 1
                        color: password.activeFocus ? "#D6B48C" : "#454545"
                    }
                }
                onAccepted: if (join.enabled)
                    join.clicked()
            }
            Row {
                spacing: 8
                ActionButton {
                    id: join
                    text: "Connect"
                    accent: true
                    fontFamily: panel.fontFamily
                    enabled: !panel.service.wifiBusy && Model.passwordValid(password.text, panel.service.passwordNetwork?.security === WifiSecurityType.Sae)
                    onClicked: {
                        panel.service.startConnection(panel.service.passwordNetwork, password.text, true);
                        password.clear();
                    }
                }
                ActionButton {
                    text: "Cancel"
                    fontFamily: panel.fontFamily
                    onClicked: {
                        password.clear();
                        panel.service.passwordNetwork = null;
                    }
                }
            }
            Label {
                width: parent.width
                text: "Your system remembers this network for next time."
            }
        }
    }
    Disclosure {
        width: parent.width
        text: "Nearby networks"
        fontFamily: panel.fontFamily
        visible: panel.service.wifiDevices.length > 0
        enabled: panel.service.wifiEnabled && !panel.service.wifiBlocked
        checked: panel.service.wifiExpanded
        onClicked: {
            panel.service.wifiExpanded = checked;
            panel.resized();
        }
    }
    Column {
        width: parent.width
        spacing: 7
        visible: panel.service.wifiExpanded && panel.service.wifiEnabled
        Label {
            width: parent.width
            visible: !panel.service.networks.length
            text: "Looking for networks nearby…"
        }
        Repeater {
            model: panel.service.networks
            Button {
                id: networkButton
                required property var modelData
                width: panel.width
                height: 58
                leftPadding: 11
                rightPadding: 11
                enabled: !panel.service.wifiBusy && !modelData.connected
                hoverEnabled: true
                Accessible.name: modelData.name
                Accessible.description: modelData.connected ? "Connected" : "Connect to network"
                onClicked: panel.service.connectNetwork(modelData)
                background: Rectangle {
                    radius: 9
                    color: networkButton.down ? "#39342F" : networkButton.hovered ? "#2D2A27" : "#242424"
                    border {
                        width: 1
                        color: networkButton.visualFocus ? "#D6B48C" : "#343434"
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }
                contentItem: Row {
                    spacing: 12
                    Label {
                        width: 23
                        anchors.verticalCenter: parent.verticalCenter
                        text: Model.wifiIcon(networkButton.modelData.signalStrength)
                        font {
                            family: "Symbols Nerd Font Mono"
                            pixelSize: 20
                        }
                        color: networkButton.modelData.connected ? "#A9C7BC" : "#D6B48C"
                    }
                    Column {
                        width: parent.width - 35
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Label {
                            width: parent.width
                            text: networkButton.modelData.name
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                            color: "#F8F9F9"
                            font {
                                pixelSize: 13
                                weight: Font.Medium
                            }
                        }
                        Label {
                            width: parent.width
                            text: networkButton.modelData.connected ? "Connected" : networkButton.modelData.stateChanging ? "Connecting…" : (networkButton.modelData.known ? "Saved · " : "") + (networkButton.modelData.security === WifiSecurityType.Open ? "Open network" : "Secured") + " · " + Model.strength(networkButton.modelData.signalStrength)
                            color: networkButton.modelData.connected ? "#A9C7BC" : "#B8B8B8"
                        }
                    }
                }
                HoverHandler {
                    cursorShape: networkButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
            }
        }
        ActionButton {
            text: "Advanced network settings"
            fontFamily: panel.fontFamily
            enabled: false
            Accessible.description: "Not available yet"
        }
    }
}
