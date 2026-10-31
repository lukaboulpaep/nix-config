import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "settings" as Settings
import "audio" as Audio
import "brightness" as Brightness
import "system" as System
import "battery" as Battery
import "connections" as NetworkControls
import "displays" as Displays

ShellRoot {
    id: shell
    property alias desktopTheme: theme
    // Match the bar's left-to-right order so page motion follows the chosen icon.
    readonly property var menus: [settings, displaysMenu, connectionsMenu, batteryMenu, systemMenu, brightnessMenu, audioMenu]
    property int switchRequest: 0
    property var pendingMenu: null
    function menuAnchorCenter(targetScreen, name) {
        const instance = screenBars.instances.find(instance => instance.barWindow.screen === targetScreen);
        return instance ? instance.barWindow.menuAnchorCenter(name) : (targetScreen?.width ?? 0) - theme.barMargin;
    }
    function claimMenu(menu) {
        for (const other of menus)
            if (other !== menu)
                other.opened = false;
    }
    function closeMenu(menu) {
        if (pendingMenu === menu) {
            switchRequest++;
            pendingMenu = null;
        }
        menu.opened = false;
    }
    function toggleMenu(menu, targetScreen) {
        const cancel = pendingMenu === menu;
        const request = ++switchRequest;
        pendingMenu = null;
        if (cancel)
            return;
        if (menu.opened && menu.screen === targetScreen) {
            menu.opened = false;
            return;
        }
        const previous = menus.find(other => other.opened);
        const slide = previous && previous !== menu && previous.card && menu.card && previous.screen === targetScreen && previous !== displaysMenu && menu !== displaysMenu;
        if (!slide) {
            menu.switchDirection = 0;
            menu.switching = false;
            menu.openOn(targetScreen);
            return;
        }
        pendingMenu = menu;
        const captured = previous.card.pageItem.grabToImage(frame => {
            if (request !== shell.switchRequest)
                return;
            shell.pendingMenu = null;
            if (!previous.opened || !Quickshell.screens.includes(targetScreen))
                return;
            menu.switchDirection = menus.indexOf(menu) > menus.indexOf(previous) ? 1 : -1;
            menu.switching = true;
            previous.switching = true;
            previous.held = true;
            menu.handoffFrom = previous;
            menu.card.prepareSwitch(frame, previous.card.width, previous.card.height);
            menu.openOn(targetScreen);
        });
        if (!captured) {
            pendingMenu = null;
            menu.switchDirection = 0;
            menu.switching = false;
            menu.openOn(targetScreen);
        }
    }
    Theme {
        id: theme
    }
    Displays.DisplayService {
        id: displayService
    }
    WorkspaceService {
        id: workspaceService
        displays: displayService
    }
    BarMetrics {
        id: barMetrics
        systemActive: systemMenu.opened
        connections: connectionService
    }
    NetworkControls.ConnectionService {
        id: connectionService
        active: connectionsMenu.opened
    }

    Settings.SettingsMenu {
        id: settings
        theme: shell.desktopTheme
        screen: Quickshell.screens[0]
        onOpenedChanged: if (opened)
            shell.claimMenu(settings)
    }

    Audio.AudioMenu {
        id: audioMenu
        anchorCenter: shell.menuAnchorCenter(screen, "audio")
        theme: shell.desktopTheme
        screen: Quickshell.screens[0]
        onOpenedChanged: if (opened)
            shell.claimMenu(audioMenu)
    }

    Brightness.BrightnessMenu {
        id: brightnessMenu
        anchorCenter: shell.menuAnchorCenter(screen, "brightness")
        theme: shell.desktopTheme
        screen: Quickshell.screens[0]
        onOpenedChanged: if (opened)
            shell.claimMenu(brightnessMenu)
    }

    System.SystemMenu {
        id: systemMenu
        anchorCenter: shell.menuAnchorCenter(screen, "system")
        theme: shell.desktopTheme
        stats: barMetrics.system
        screen: Quickshell.screens[0]
        onOpenedChanged: if (opened)
            shell.claimMenu(systemMenu)
    }

    Battery.BatteryMenu {
        id: batteryMenu
        anchorCenter: shell.menuAnchorCenter(screen, "battery")
        theme: shell.desktopTheme
        screen: Quickshell.screens[0]
        onOpenedChanged: if (opened)
            shell.claimMenu(batteryMenu)
    }

    NetworkControls.ConnectionsMenu {
        id: connectionsMenu
        anchorCenter: shell.menuAnchorCenter(screen, "connections")
        theme: shell.desktopTheme
        service: connectionService
        screen: Quickshell.screens[0]
        onOpenedChanged: if (opened)
            shell.claimMenu(connectionsMenu)
    }

    Displays.DisplayMenu {
        id: displaysMenu
        theme: shell.desktopTheme
        service: displayService
        screen: Quickshell.screens[0]
        onOpenedChanged: if (opened)
            shell.claimMenu(displaysMenu)
    }

    IpcHandler {
        target: "displays"
        function toggle(): string {
            shell.toggleMenu(displaysMenu, Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]);
            return displaysMenu.opened ? "Opened" : "Closed";
        }
        function status(): string {
            return displaysMenu.opened ? "Opened" : "Closed";
        }
        function close(): string {
            shell.closeMenu(displaysMenu);
            return "Closed";
        }
    }

    IpcHandler {
        target: "connections"
        function toggle(): string {
            shell.toggleMenu(connectionsMenu, Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]);
            return connectionsMenu.opened ? "Opened" : "Closed";
        }
        function status(): string {
            return connectionsMenu.opened ? "Opened" : "Closed";
        }
        function close(): string {
            shell.closeMenu(connectionsMenu);
            return "Closed";
        }
    }

    IpcHandler {
        target: "battery"
        function toggle(): string {
            shell.toggleMenu(batteryMenu, Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]);
            return batteryMenu.opened ? "Opened" : "Closed";
        }
        function status(): string {
            return batteryMenu.opened ? "Opened" : "Closed";
        }
        function close(): string {
            shell.closeMenu(batteryMenu);
            return "Closed";
        }
    }

    IpcHandler {
        target: "system"
        function toggle(): string {
            shell.toggleMenu(systemMenu, Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]);
            return systemMenu.opened ? "Opened" : "Closed";
        }
        function status(): string {
            return systemMenu.opened ? "Opened" : "Closed";
        }
        function close(): string {
            shell.closeMenu(systemMenu);
            return "Closed";
        }
    }

    IpcHandler {
        target: "brightness"
        function toggle(): string {
            shell.toggleMenu(brightnessMenu, Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]);
            return brightnessMenu.opened ? "Opened" : "Closed";
        }
        function status(): string {
            return brightnessMenu.opened ? "Opened" : "Closed";
        }
        function refresh(): string {
            brightnessMenu.refreshValues();
            return "Refreshed";
        }
        function close(): string {
            shell.closeMenu(brightnessMenu);
            return "Closed";
        }
    }

    IpcHandler {
        target: "audio"
        function toggle(): string {
            shell.toggleMenu(audioMenu, Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]);
            return audioMenu.opened ? "Opened" : "Closed";
        }
        function status(): string {
            return audioMenu.opened ? "Opened" : "Closed";
        }
        function close(): string {
            shell.closeMenu(audioMenu);
            return "Closed";
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): string {
            shell.toggleMenu(settings, Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]);
            return settings.opened ? "Opened" : "Closed";
        }
        function openPage(page: string): string {
            const session = ["lock", "suspend", "reboot", "poweroff"].includes(page);
            if (!session && !["", "appearance", "bluetooth", "system", "information"].includes(page))
                return "Unknown settings page";
            settings.openOn(Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]);
            // This IPC only opens a page; session actions still need a click.
            settings.action = session ? page : "";
            settings.page = session ? "session" : page;
            return "Opened";
        }
        function status(): string {
            return settings.opened ? "Opened" : "Closed";
        }
        function close(): string {
            shell.closeMenu(settings);
            return "Closed";
        }
    }

    Variants {
        id: screenBars
        model: Quickshell.screens

        Scope {
            required property var modelData
            property alias barWindow: bar

            PanelWindow {
                screen: modelData
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.namespace: "quickshell-wallpaper"
                color: theme.barBackground

                Image {
                    anchors.fill: parent
                    source: theme.wallpaperSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Bar {
                id: bar
                screen: modelData
                backgroundColor: theme.barTint
                backgroundOpacity: theme.barOpacity
                textColor: theme.barForeground
                edgeMargin: theme.barMargin
                cornerRadius: theme.barRadius
                fontFamily: theme.fontFamily
                fontSize: theme.fontSize
                surfaceHeight: theme.barHeight
                metrics: barMetrics
                workspaceEntries: workspaceService.entries
                wallpaperSource: theme.wallpaperSource
                displaysOpened: displaysMenu.opened && displaysMenu.screen === bar.screen
                onDisplaysRequested: shell.toggleMenu(displaysMenu, bar.screen)
                connectionsOpened: connectionsMenu.opened && connectionsMenu.screen === bar.screen
                onConnectionsRequested: shell.toggleMenu(connectionsMenu, bar.screen)
                batteryOpened: batteryMenu.opened && batteryMenu.screen === bar.screen
                onBatteryRequested: shell.toggleMenu(batteryMenu, bar.screen)
                systemOpened: systemMenu.opened && systemMenu.screen === bar.screen
                onSystemRequested: shell.toggleMenu(systemMenu, bar.screen)
                audioOpened: audioMenu.opened && audioMenu.screen === bar.screen
                brightnessOpened: brightnessMenu.opened && brightnessMenu.screen === bar.screen
                displayBrightness: brightnessMenu.values[bar.screen.name] ?? -1
                onBrightnessRequested: shell.toggleMenu(brightnessMenu, bar.screen)
                onAudioRequested: shell.toggleMenu(audioMenu, bar.screen)
                onSettingsRequested: shell.toggleMenu(settings, bar.screen)
            }
        }
    }
}
