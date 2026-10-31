import QtQuick
import QtQuick.Effects

Item {
    id: group
    default property alias content: contentRow.data
    required property color backgroundColor
    required property real backgroundOpacity
    required property int cornerRadius
    required property int surfaceHeight
    property int horizontalPadding: 10

    implicitWidth: contentRow.implicitWidth + 2 * horizontalPadding
    implicitHeight: surfaceHeight

    RectangularShadow {
        anchors.fill: surface
        radius: surface.radius
        blur: 6
        offset.y: 2
        color: Qt.rgba(0, 0, 0, 0.18)
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: group.cornerRadius
        color: Qt.rgba(group.backgroundColor.r, group.backgroundColor.g, group.backgroundColor.b, group.backgroundOpacity)
        antialiasing: true
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 14
    }
}
