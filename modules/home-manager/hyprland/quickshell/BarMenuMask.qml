import Quickshell

// Leave the bar reachable even while a menu owns the area below it.
Region {
    required property var menuWindow
    required property real barBottom
    x: 0
    y: barBottom
    width: menuWindow.opened ? menuWindow.width : 0
    height: menuWindow.opened ? Math.max(0, menuWindow.height - barBottom) : 0
}
