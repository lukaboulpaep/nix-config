import QtQuick
import QtCore
import Quickshell
import Quickshell.Io

Scope {
    id: theme

    readonly property var tokens: JSON.parse(tokenFile.text())
    readonly property string mode: ["light", "dark"].includes(modeFile.text().trim()) ? modeFile.text().trim() : tokens.defaultMode
    readonly property var palette: tokens.palettes[mode]
    readonly property color barBackground: palette.frame
    // Pond uses Onest and charcoal surfaces. This denser glass treatment
    // follows the launcher reference; Hyprland supplies the backdrop blur.
    // https://github.com/bflycomputer/pond-interface/blob/main/shell/Theme.qml
    // Upstream notice: licenses/pond-interface.txt
    readonly property color barTint: "#1D1D1D"
    readonly property real barOpacity: 0.64
    readonly property color barForeground: "#F8F9F9"
    readonly property color foreground: palette.foreground
    readonly property color accent: palette.accent
    readonly property string fontFamily: shellFont.status === FontLoader.Ready ? shellFont.name : tokens.fonts.ui
    // Shell-specific sizing lives here so it reloads with the QML files.
    readonly property int fontSize: 12
    readonly property int barHeight: 28
    readonly property int barMargin: 8
    readonly property int barRadius: 12

    readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/desktop-theme"
    readonly property var wallpapers: [
        {
            id: "magnolia",
            name: "Magnolia",
            prefix: "magnolia-"
        },
        {
            id: "ribbons",
            name: "Paper ribbons",
            prefix: "ribbons-"
        },
        {
            id: "ginkgo",
            name: "Ginkgo",
            prefix: "ginkgo-"
        },
        {
            id: "dunes",
            name: "Dunes",
            prefix: ""
        },
        {
            id: "orbits",
            name: "Orbits",
            prefix: "orbits-"
        },
        {
            id: "facets",
            name: "Facets",
            prefix: "facets-"
        }
    ]
    readonly property string wallpaperId: {
        const saved = wallpaperFile.text().trim();
        return wallpapers.some(wallpaper => wallpaper.id === saved) ? saved : "ginkgo";
    }
    readonly property url wallpaperSource: wallpaperUrl(wallpaperId, mode)
    readonly property bool wallpaperSaving: wallpaperWriter.running
    property string wallpaperError: ""

    function wallpaperUrl(id: string, colorMode: string): string {
        const wallpaper = wallpapers.find(entry => entry.id === id) || wallpapers.find(entry => entry.id === "ginkgo");
        return "file:///etc/nixos/assets/wallpapers/" + wallpaper.prefix + (colorMode === "dark" ? "dark" : "light") + ".png";
    }

    function selectWallpaper(id: string): string {
        if (!wallpapers.some(wallpaper => wallpaper.id === id))
            return "Unknown wallpaper";
        if (wallpaperWriter.running)
            return "Wallpaper change in progress";
        wallpaperError = "";
        wallpaperWriter.command = ["sh", "-c", 'set -eu; mkdir -p "$1"; temporary=$(mktemp "$1/.wallpaper.XXXXXX"); ' + 'trap \'rm -f "$temporary"\' EXIT; printf "%s\\n" "$2" > "$temporary"; ' + 'mv "$temporary" "$1/wallpaper"', "wallpaper-save", stateDirectory, id];
        wallpaperWriter.running = true;
        return "Applying " + id;
    }

    FontLoader {
        id: shellFont
        // Onest is Pond's UI face. Load it locally so QML reloads need no rebuild.
        // Google Fonts revision 5174b3333331c966c38f4355d50b03ca1c1df2f9, ofl/onest.
        // Copyright and SIL OFL: /etc/nixos/assets/fonts/OFL-Onest.txt
        source: "file:///etc/nixos/assets/fonts/Onest.ttf"
    }

    FileView {
        id: tokenFile
        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/desktop-theme/tokens.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: modeFile
        path: theme.stateDirectory + "/mode"
        blockLoading: true
        printErrors: false // The switch command creates this on first launch.
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: wallpaperFile
        path: theme.stateDirectory + "/wallpaper"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
    }

    Process {
        id: wallpaperWriter
        onExited: exitCode => {
            if (exitCode === 0)
                wallpaperFile.reload();
            else
                theme.wallpaperError = "Could not save the wallpaper. Please try again.";
        }
    }

    IpcHandler {
        target: "wallpaper"
        function get(): string {
            return theme.wallpaperId;
        }
        function list(): string {
            return theme.wallpapers.map(entry => entry.id).join("\n");
        }
        function set(id: string): string {
            return theme.selectWallpaper(id);
        }
    }

    Process {
        id: switcher
        onExited: (exitCode, exitStatus) => {
            modeFile.reload();
            if (exitCode !== 0)
                console.error("Could not apply desktop theme (exit " + exitCode + ")");
        }
    }

    function apply(mode: string): string {
        if (switcher.running)
            return "Theme change in progress";
        switcher.command = [tokens.applyCommand, mode];
        switcher.running = true;
        return "Applying " + mode;
    }

    Component.onCompleted: apply("apply")

    IpcHandler {
        target: "theme"

        function get(): string {
            return theme.mode;
        }

        function set(mode: string): string {
            if (mode !== "light" && mode !== "dark")
                return "Use light or dark";
            return theme.apply(mode);
        }

        function toggle(): string {
            return set(theme.mode === "light" ? "dark" : "light");
        }
    }
}
