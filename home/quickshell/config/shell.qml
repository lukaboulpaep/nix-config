//@ pragma UseQApplication

import Quickshell
import Quickshell.Wayland

import "components"
import "modules"
import "services" as Services

Scope {
    id: root

    Variants {
        model: Quickshell.screens

        delegate: Bar {
            required property var modelData

            screen: modelData
            primary: modelData.name === Services.DisplayService.primaryMonitor
        }
    }

    NetworkPopup {}
    BluetoothPopup {}
    BatteryPopup {}
    AudioPopup {}
    BrightnessPopup {}
    CalendarPopup {}
    NotificationPopup {}
    Notifications {}

    // dmenu-style surfaces.
    AppLauncher {}
    WallpaperPicker {}
    ThemePicker {}
}
