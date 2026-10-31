import QtQuick

Rectangle {
    id: frame
    required property string title
    required property string fontFamily
    required property string titleFontFamily
    default property alias pageContent: body.data
    signal back
    implicitWidth: 440
    implicitHeight: body.implicitHeight + 94
    color: "#1D1D1D"
    radius: 16

    data: Item {
        anchors.fill: parent
        SettingsButton {
            x: 16
            y: 14
            width: 40
            implicitWidth: 40
            implicitHeight: 40
            padding: 8
            fontFamily: frame.fontFamily
            Accessible.name: "Back to settings"
            fillColor: "transparent"
            contentItem: Image {
                source: "icons/chevron-left.svg"
                sourceSize.width: 24
                sourceSize.height: 24
                fillMode: Image.PreserveAspectFit
            }
            onClicked: frame.back()
        }
        Text {
            x: 62
            y: 21
            text: frame.title
            font {
                family: frame.titleFontFamily
                pixelSize: 23
            }
            color: "#F8F9F9"
        }
        Column {
            id: body
            x: 24
            y: 70
            width: parent.width - 48
            spacing: 16
        }
        // Keep clicks on empty panel space from dismissing the overlay.
        MouseArea {
            anchors.fill: parent
            z: -1
        }
    }
}
