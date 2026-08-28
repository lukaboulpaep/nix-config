import QtQuick

import "../core" as Core
import "../services" as Services
import "../components" as Components

// BrightnessPopup

Components.PopupSurface {
    id: popup

    popupId: "brightness"

    cardWidth: 310
    maxCardHeight: 180

    readonly property var svc: Services.BrightnessService

    readonly property string monitorName: Core.PopupManager.screen ? Core.PopupManager.screen.name : ""

    readonly property int level: popup.svc.levelFor(popup.monitorName)

    readonly property real fraction: popup.level < 0 ? 0 : popup.level / 100

    readonly property bool internal: popup.svc.isInternalMonitor(popup.monitorName)

    contentComponent: Component {

        Column {
            id: body

            spacing: Core.Theme.spacing

            Components.PopupHeader {
                width: body.width

                title: "Brightness"
                subtitle: popup.internal
                    ? popup.svc.available
                        ? "Built-in display · minimum " + popup.svc.minimumLevel + "%"
                        : "No backlight detected"
                    : popup.level < 0
                        ? "External display · use keys or wheel to read"
                        : "External display · DDC/CI"
            }

            Rectangle {
                width: body.width
                height: 76

                radius: Core.Theme.radiusRow

                color: Core.Theme.surface

                Column {
                    anchors.fill: parent
                    anchors.margins: 12

                    spacing: 8

                    Item {
                        width: parent.width
                        height: 20

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            text: Core.Icons.forBrightness(popup.fraction)

                            font.family: Core.Theme.fontFamily
                            font.pixelSize: 17

                            color: Core.Theme.accent
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            text: popup.level < 0 ? "--" : popup.level + "%"

                            font.family: Core.Theme.fontFamily
                            font.pixelSize: Core.Theme.fontSizeLarge
                            font.weight: Font.DemiBold

                            color: Core.Theme.foreground
                        }
                    }

                    Components.VolumeSlider {
                        width: parent.width

                        value: popup.fraction
                        minimumValue: popup.svc.minimumFractionFor(popup.monitorName)
                        enabled: popup.svc.availableFor(popup.monitorName) && popup.level >= 0

                        fillColor: Core.Theme.accent

                        onMoved: function (value) {
                            popup.svc.setPercent(value * 100, popup.monitorName);
                        }
                    }
                }
            }
        }
    }
}
