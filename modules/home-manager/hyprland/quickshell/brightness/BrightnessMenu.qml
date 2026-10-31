pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

import ".." as BarComponents

PanelWindow {
    id: menu
    required property var theme
    property bool opened: false
    property int switchDirection: 0
    property alias switching: scene.switching
    property alias held: scene.held
    property var handoffFrom: null
    readonly property Item card: panel
    property real anchorCenter: width - theme.barMargin
    property bool individualExpanded: false
    property alias values: service.values
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    mask: BarComponents.BarMenuMask {
        menuWindow: menu
        barBottom: menu.theme.barMargin + menu.theme.barHeight
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-brightness"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    visible: opened || scene.visible
    function openOn(targetScreen) {
        screen = targetScreen;
        opened = true;
    }
    function refreshValues() {
        service.refresh();
    }
    onOpenedChanged: if (opened) {
        scene.forceActiveFocus();
        scroll.contentY = 0;
    }
    BrightnessService {
        id: service
        active: menu.opened
    }

    component Label: Text {
        textFormat: Text.PlainText
        color: "#B8B8B8"
        font {
            family: menu.theme.fontFamily
            pixelSize: 12
        }
        wrapMode: Text.WordWrap
    }
    component BrightnessControl: Column {
        id: control
        required property string label
        required property int level
        property bool available: true
        property bool mixed: false
        signal changeRequested(real value, bool verify)
        spacing: 8
        Row {
            width: parent.width
            Label {
                width: parent.width - 64
                text: control.label
                color: "#F8F9F9"
                font {
                    pixelSize: 13
                    weight: Font.Medium
                }
            }
            Label {
                width: 64
                horizontalAlignment: Text.AlignRight
                text: !control.available ? "—" : control.mixed ? "Mixed" : control.level + "%"
                color: "#D6B48C"
                font.pixelSize: 13
            }
        }
        Slider {
            id: slider
            width: parent.width
            height: 32
            from: service.minimum
            to: 100
            stepSize: 1
            enabled: control.available
            Accessible.name: control.label + " brightness"
            Accessible.description: "Minimum " + service.minimum + " percent, maximum 100 percent"
            Binding {
                target: slider
                property: "value"
                value: Math.max(service.minimum, control.level)
                when: !slider.pressed
                restoreMode: Binding.RestoreNone
            }
            onMoved: control.changeRequested(value, !pressed)
            onPressedChanged: if (!pressed)
                control.changeRequested(value, true)
            background: Rectangle {
                x: slider.leftPadding
                y: (slider.height - height) / 2
                width: slider.availableWidth
                height: 5
                radius: 3
                color: "#383838"
                Rectangle {
                    width: parent.width * slider.visualPosition
                    height: parent.height
                    radius: 3
                    color: slider.enabled ? "#D6B48C" : "#777777"
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: (slider.height - height) / 2
                width: 14
                height: 14
                radius: 7
                color: slider.pressed || slider.visualFocus ? "#D6B48C" : "#F8F9F9"
                opacity: slider.enabled ? 1 : 0.4
            }
            HoverHandler {
                cursorShape: slider.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
        }
    }
    BarComponents.BarMenuScene {
        id: scene
        opened: menu.opened
        Keys.onEscapePressed: menu.opened = false
        MouseArea {
            anchors.fill: parent
            onClicked: menu.opened = false
        }
        RectangularShadow {
            anchors.fill: panel
            radius: panel.radius
            blur: 20
            offset.y: 4
            color: "#50000000"
        }
        BarComponents.BarMenuCard {
            id: panel
            menuWindow: menu
            objectName: "brightnessPanel"
            anchors {
                top: parent.top
                topMargin: menu.theme.barMargin + menu.theme.barHeight + 8
            }
            x: Math.max(menu.theme.barMargin, Math.min(menu.anchorCenter - width / 2, (menu.screen?.width ?? menu.width) - width - menu.theme.barMargin))
            width: Math.min(400, (menu.screen?.width ?? menu.width) - 2 * menu.theme.barMargin)
            height: Math.min(body.implicitHeight + 86, menu.height - y - 16)
            color: "#1D1D1D"
            radius: 16
            border {
                width: 1
                color: "#383838"
            }
            MouseArea {
                anchors.fill: parent
            }
            Text {
                x: 22
                y: 18
                text: "Brightness"
                color: "#F8F9F9"
                font {
                    family: "serif"
                    pixelSize: 23
                }
            }
            Flickable {
                id: scroll
                anchors {
                    fill: parent
                    leftMargin: 22
                    rightMargin: 22
                    topMargin: 64
                    bottomMargin: 22
                }
                contentHeight: body.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
                Column {
                    id: body
                    width: scroll.width
                    spacing: 20
                    Label {
                        width: parent.width
                        text: "Adjust your displays together. Minimum brightness is " + service.minimum + "%."
                    }
                    BrightnessControl {
                        width: parent.width
                        label: "All displays"
                        level: service.combinedValue
                        available: service.controllableCount > 0
                        mixed: service.mixedValues
                        onChangeRequested: (value, verify) => service.setAllBrightness(value, verify)
                    }
                    Label {
                        width: parent.width
                        visible: service.mixedValues
                        text: "Your displays have different levels. Move the slider to match them."
                    }
                    Label {
                        width: parent.width
                        visible: service.displays.count === 0 || service.error.length > 0
                        text: service.error || (service.busy ? "Finding your displays…" : "No displays available.")
                    }
                    Label {
                        width: parent.width
                        visible: service.displays.count > service.controllableCount
                        text: "Some displays can’t be adjusted. See individual displays below."
                    }
                    Label {
                        width: parent.width
                        visible: service.displayErrorCount > 0 && !menu.individualExpanded
                        text: "A display didn’t apply the change. Open individual displays for details."
                        color: "#EBA095"
                    }
                    Column {
                        width: parent.width
                        spacing: 12
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: "#383838"
                        }
                        Button {
                            id: individualButton
                            width: parent.width
                            height: 32
                            leftPadding: 3
                            rightPadding: 9
                            topPadding: 0
                            bottomPadding: 0
                            text: "Individual displays"
                            checkable: true
                            checked: menu.individualExpanded
                            onClicked: menu.individualExpanded = checked
                            Accessible.description: checked ? "Expanded" : "Collapsed"
                            background: Rectangle {
                                radius: 6
                                color: individualButton.down ? "#39342F" : individualButton.hovered || individualButton.visualFocus ? "#302C28" : "transparent"
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }
                            contentItem: Item {
                                Label {
                                    anchors {
                                        left: parent.left
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: individualButton.text
                                    color: "#B8B8B8"
                                    font.pixelSize: 13
                                }
                                Shape {
                                    anchors {
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: 16
                                    height: 16
                                    antialiasing: true
                                    rotation: menu.individualExpanded ? 90 : 0
                                    Behavior on rotation {
                                        NumberAnimation {
                                            duration: 120
                                        }
                                    }
                                    ShapePath {
                                        strokeColor: "#D6B48C"
                                        strokeWidth: 1.5
                                        fillColor: "transparent"
                                        capStyle: ShapePath.RoundCap
                                        joinStyle: ShapePath.RoundJoin
                                        startX: 6
                                        startY: 3.5
                                        PathLine {
                                            x: 10.5
                                            y: 8
                                        }
                                        PathLine {
                                            x: 6
                                            y: 12.5
                                        }
                                    }
                                }
                            }
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                        Column {
                            width: parent.width
                            spacing: 20
                            visible: menu.individualExpanded
                            Repeater {
                                model: service.displays
                                Column {
                                    id: display
                                    required property string displayId
                                    required property string name
                                    required property int value
                                    required property bool supported
                                    required property string message
                                    required property string error
                                    width: body.width
                                    spacing: 8
                                    BrightnessControl {
                                        width: parent.width
                                        label: display.name
                                        level: display.value
                                        available: display.supported
                                        onChangeRequested: (value, verify) => service.setBrightness(display.displayId, value, verify)
                                    }
                                    Label {
                                        width: parent.width
                                        visible: text.length > 0
                                        text: display.error || display.message
                                        color: display.error ? "#EBA095" : "#B8B8B8"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
