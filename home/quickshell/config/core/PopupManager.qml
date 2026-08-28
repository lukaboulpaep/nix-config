pragma Singleton

import QtQuick

// PopupManager

QtObject {
    id: root

    // Currently open popup id ("" == nothing open)
    property string current: ""

    // Screen-space anchor supplied by the bar module that opened it
    property real anchorCenter: 0
    property real anchorBottom: 0

    // Screen whose bar module opened the current popup.
    property var screen: null

    // A nested context menu is open somewhere (used to keep the parent popup from closing on outside-click pass-through)
    property bool contextMenuOpen: false

    // Do-not-disturb.
    property bool dnd: false

    function isOpen(id, screen) {
        if (root.current !== id)
            return false;

        return screen === undefined || screen === null || root.screen === screen;
    }

    function open(id, center, bottom, screen) {
        root.anchorCenter = center;
        root.anchorBottom = bottom;

        if (screen !== undefined && screen !== null)
            root.screen = screen;

        root.current = id;
    }

    function toggle(id, center, bottom, screen) {
        if (root.isOpen(id, screen)) {
            root.close();
            return;
        }

        root.open(id, center, bottom, screen);
    }

    function close() {
        root.contextMenuOpen = false;
        root.current = "";
    }
}
