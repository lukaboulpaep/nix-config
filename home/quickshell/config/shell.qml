//@ pragma UseQApplication

import Quickshell
import Quickshell.Wayland

import "components"
import "modules"

Scope {
    id: root
    Bar {}
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
