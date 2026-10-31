import QtQuick
import QtQuick.Shapes

Item {
    id: gauge
    property int percentage: -1
    property bool charging: false
    property bool plugged: false
    property bool animate: false
    property string fontFamily: "sans-serif"
    readonly property color accent: percentage >= 0 && percentage <= 15 && !plugged ? "#EBA095" : charging || plugged ? "#A9C7BC" : "#D6B48C"
    implicitWidth: 244
    implicitHeight: 108
    Accessible.role: Accessible.StaticText
    Accessible.name: percentage < 0 ? "Battery unavailable" : "Battery " + percentage + " percent"
    Rectangle {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: 9
        height: 34
        radius: 4
        color: gauge.accent
        opacity: 0.65
    }
    Rectangle {
        id: casing
        width: parent.width - 13
        height: parent.height
        radius: 20
        color: "#1D1D1D"
        border {
            width: 2
            color: gauge.accent
        }
        Rectangle {
            id: charge
            x: 7
            y: 7
            height: parent.height - 14
            width: (parent.width - 14) * Math.max(0, Math.min(100, gauge.percentage)) / 100
            radius: 13
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(gauge.accent.r, gauge.accent.g, gauge.accent.b, 0.34)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(gauge.accent.r, gauge.accent.g, gauge.accent.b, 0.12)
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 450
                    easing.type: Easing.OutCubic
                }
            }
            Item {
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                visible: gauge.charging && width > 0
                Rectangle {
                    id: shimmer
                    width: 64
                    height: parent.height
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 0.5
                            color: "#33FFFFFF"
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }
                    NumberAnimation on x {
                        from: -64
                        to: charge.width
                        duration: 1900
                        loops: Animation.Infinite
                        running: gauge.animate && gauge.charging
                    }
                }
            }
        }
        Row {
            anchors.centerIn: parent
            spacing: 9
            Shape {
                visible: gauge.charging
                width: 18
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                ShapePath {
                    strokeWidth: 0
                    strokeColor: "transparent"
                    fillColor: gauge.accent
                    startX: 11
                    startY: 0
                    PathLine {
                        x: 1
                        y: 17
                    }
                    PathLine {
                        x: 8
                        y: 17
                    }
                    PathLine {
                        x: 6
                        y: 30
                    }
                    PathLine {
                        x: 18
                        y: 12
                    }
                    PathLine {
                        x: 11
                        y: 12
                    }
                    PathLine {
                        x: 11
                        y: 0
                    }
                }
                SequentialAnimation on opacity {
                    running: gauge.animate && gauge.charging
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 0.55
                        to: 1
                        duration: 950
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 1
                        to: 0.55
                        duration: 950
                        easing.type: Easing.InOutSine
                    }
                }
            }
            Text {
                text: gauge.percentage < 0 ? "—" : gauge.percentage + "%"
                color: "#F8F9F9"
                font {
                    family: gauge.fontFamily
                    pixelSize: 38
                    weight: Font.Medium
                }
            }
        }
    }
}
