import QtQuick

Item {
    id: scene
    required property bool opened
    property bool switching: false
    property bool held: false
    anchors.fill: parent
    opacity: opened || held ? 1 : 0
    visible: opacity > 0
    enabled: opened
    focus: opened
    Behavior on opacity {
        enabled: !scene.switching
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }
}
