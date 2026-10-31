import QtQuick

Item {
    id: indicator
    required property string icon
    property string label: ""
    property string description: label
    required property color foreground
    required property string fontFamily
    required property int fontSize
    property int maximumLabelWidth: 120

    implicitWidth: content.implicitWidth
    implicitHeight: 24
    Accessible.role: Accessible.StaticText
    Accessible.name: description

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            text: indicator.icon
            color: indicator.foreground
            // The exact glyph family used by HyperFlow's Waybar configuration.
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: indicator.label.length > 0
            text: indicator.label
            textFormat: Text.PlainText
            width: Math.min(implicitWidth, indicator.maximumLabelWidth)
            elide: Text.ElideRight
            color: indicator.foreground
            font.family: indicator.fontFamily
            font.pixelSize: indicator.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
