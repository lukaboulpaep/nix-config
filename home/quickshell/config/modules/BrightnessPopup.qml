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

    contentComponent: Component {

        Column {
            id: body

            spacing: Core.Theme.spacing

            Components.PopupHeader {
                width: body.width

                title: "Brightness"
                subtitle: popup.svc.available ? "Built-in display · minimum " + popup.svc.minimumLevel + "%" : "No backlight detected"
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

                            text: Core.Icons.forBrightness(popup.svc.fraction)

                            font.family: Core.Theme.fontFamily
                            font.pixelSize: 17

                            color: Core.Theme.accent
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            text: popup.svc.level + "%"

                            font.family: Core.Theme.fontFamily
                            font.pixelSize: Core.Theme.fontSizeLarge
                            font.weight: Font.DemiBold

                            color: Core.Theme.foreground
                        }
                    }

                    Components.VolumeSlider {
                        width: parent.width

                        value: popup.svc.fraction
                        minimumValue: popup.svc.minimumFraction
                        enabled: popup.svc.available

                        fillColor: Core.Theme.accent

                        onMoved: function (value) {
                            popup.svc.setPercent(value * 100);
                        }
                    }
                }
            }
        }
    }
}
