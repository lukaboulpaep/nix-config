import QtQuick
import QtQuick.Controls

Button {
    id: card
    required property string label
    required property url previewSource
    required property string fontFamily
    property bool selected: false
    implicitWidth: 188
    implicitHeight: 140
    padding: 8
    hoverEnabled: true
    Accessible.name: label + (selected ? ", selected" : "")
    Accessible.description: "Apply this wallpaper"

    background: Rectangle {
        radius: 12
        color: card.hovered || card.visualFocus ? "#383838" : "#282828"
        border.width: card.selected || card.visualFocus ? 2 : 0
        border.color: "#D6B48C"
        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }
    }

    contentItem: Item {
        Image {
            width: parent.width
            height: parent.height - 30
            source: card.previewSource
            sourceSize.width: 640
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Text {
            anchors {
                left: parent.left
                right: check.left
                bottom: parent.bottom
                bottomMargin: 3
            }
            text: card.label
            textFormat: Text.PlainText
            color: "#F8F9F9"
            font {
                family: card.fontFamily
                pixelSize: 13
            }
            elide: Text.ElideRight
        }
        Text {
            id: check
            anchors {
                right: parent.right
                bottom: parent.bottom
                bottomMargin: 3
            }
            width: 20
            text: card.selected ? "✓" : ""
            color: "#D6B48C"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignRight
        }
    }
}
