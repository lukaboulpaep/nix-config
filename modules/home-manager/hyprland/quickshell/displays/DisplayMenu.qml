pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../connections" as Controls
import "DisplayModel.js" as Model

import ".." as BarComponents

PanelWindow {
    id: menu
    required property var theme
    required property var service
    property bool opened: false
    property int switchDirection: 0
    property alias switching: scene.switching
    property alias held: scene.held
    property var handoffFrom: null
    readonly property Item card: panel
    property bool dirty: false
    property bool previews: true
    property bool layoutsExpanded: false
    property bool connectionExpanded: false
    property string selected: ""
    property string removeId: ""
    property var draft: ({
            mode: "extend",
            primary: "",
            positions: {}
        })
    readonly property var selectedDisplay: service.displays.find(d => d.id === selected) ?? null
    readonly property bool editable: service.ready && !service.busy && !service.pending
    property string connectionSignature: ""
    property bool relocating: false
    property int layoutGeneration: -1
    function resetDraft() {
        draft = Model.copy(service.layout);
        dirty = false;
        if (!service.displays.some(d => d.id === selected))
            selected = draft.primary || service.displays[0]?.id || "";
    }
    function edit(layout) {
        draft = layout;
        dirty = JSON.stringify(draft) !== JSON.stringify(service.layout);
    }
    function openOn(targetScreen) {
        screen = targetScreen;
        resetDraft();
        opened = true;
        service.refresh();
    }
    function settle() {
        Qt.callLater(() => scroll.contentItem.returnToBounds());
    }
    function applyDraft() {
        service.send("apply", {
            layout: draft
        });
    }
    function loadProfile(profile) {
        service.send("load", {
            id: profile.id
        });
    }
    Timer {
        id: settleWindow
        interval: 80
        property int attempts: 0
        onTriggered: {
            const source = menu.service.displays.find(d => d.id === menu.service.layout.primary);
            const name = menu.service.layout.mode === "mirror" ? source?.name : menu.service.pointerScreen;
            const target = Quickshell.screens.find(s => s.name === name);
            // Wayland can announce the returning independent output after the
            // helper has replied. Remap only this popup once it is available.
            if (!target && attempts++ < 12) {
                restart();
                return;
            }
            menu.screen = target ?? Quickshell.screens.find(s => s === menu.screen) ?? Quickshell.screens[0];
            menu.relocating = false;
            if (menu.opened)
                scene.forceActiveFocus();
        }
    }
    Connections {
        target: menu.service
        function onLayoutChanging() {
            settleWindow.stop();
            menu.relocating = true;
        }
        function onPendingChanged() {
            if (menu.service.pending) {
                menu.opened = true;
                scroll.contentItem.contentY = 0;
            }
        }
        function onUpdated() {
            const signature = menu.service.displays.map(d => d.id).sort().join("\n");
            if (!menu.dirty || menu.service.pending || signature !== menu.connectionSignature)
                menu.resetDraft();
            menu.connectionSignature = signature;
            if ((menu.relocating && !settleWindow.running) || (menu.opened && menu.layoutGeneration !== menu.service.generation)) {
                menu.relocating = true;
                settleWindow.attempts = 0;
                settleWindow.restart();
            }
            menu.layoutGeneration = menu.service.generation;
        }
    }
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
    WlrLayershell.namespace: "quickshell-displays"
    WlrLayershell.keyboardFocus: opened && !relocating ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    visible: !relocating && (opened || scene.visible)
    onOpenedChanged: if (opened) {
        scene.forceActiveFocus();
        scroll.contentItem.contentY = 0;
    }
    component Label: Text {
        textFormat: Text.PlainText
        color: "#B8B8B8"
        wrapMode: Text.WordWrap
        font {
            family: menu.theme.fontFamily
            pixelSize: 12
        }
    }
    component Action: Controls.ActionButton {
        fontFamily: menu.theme.fontFamily
    }
    BarComponents.BarMenuScene {
        id: scene
        opened: menu.opened
        Keys.onEscapePressed: {
            if (menu.service.pending)
                menu.service.send("revert");
            else
                menu.opened = false;
        }
        MouseArea {
            anchors.fill: parent
            // Keep the confirmation accessible throughout the layout trial.
            onClicked: if (!menu.service.pending)
                menu.opened = false
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
            objectName: "displayPanel"
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: menu.theme.barMargin + 46
                topMargin: menu.theme.barMargin + menu.theme.barHeight + 8
            }
            width: Math.min(460, menu.width - x - menu.theme.barMargin)
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
                text: "Displays"
                color: "#F8F9F9"
                font {
                    family: "serif"
                    pixelSize: 23
                }
            }
            ScrollView {
                id: scroll
                objectName: "displayScroll"
                anchors {
                    fill: parent
                    leftMargin: 22
                    rightMargin: 22
                    topMargin: 64
                    bottomMargin: 22
                }
                contentWidth: availableWidth
                contentHeight: body.implicitHeight
                clip: true
                Component.onCompleted: contentItem.boundsBehavior = Flickable.StopAtBounds
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                    contentItem: Rectangle {
                        radius: 2
                        color: parent.pressed ? "#D6B48C" : "#62605C"
                        opacity: parent.active ? 1 : 0.5
                    }
                    background: Item {}
                }
                Column {
                    id: body
                    width: scroll.availableWidth - 8
                    spacing: 14
                    Rectangle {
                        width: parent.width
                        height: confirmation.implicitHeight + 24
                        visible: menu.service.pending
                        radius: 9
                        color: "#302B25"
                        border {
                            width: 1
                            color: "#D6B48C"
                        }
                        Column {
                            id: confirmation
                            x: 12
                            y: 12
                            width: parent.width - 24
                            spacing: 9
                            Label {
                                width: parent.width
                                text: "Keep this layout? Reverting in " + menu.service.remaining + "s"
                                color: "#F8F9F9"
                            }
                            Row {
                                spacing: 8
                                Action {
                                    text: "Keep changes"
                                    objectName: "keepDisplayChanges"
                                    accent: true
                                    enabled: !menu.service.busy
                                    onClicked: menu.service.send("keep")
                                }
                                Action {
                                    text: "Revert"
                                    enabled: !menu.service.busy
                                    onClicked: menu.service.send("revert")
                                }
                            }
                        }
                    }
                    Label {
                        width: parent.width
                        visible: menu.service.error.length > 0
                        text: menu.service.error
                        color: "#EBA095"
                    }
                    Action {
                        text: "Retry"
                        visible: !menu.service.ready
                        onClicked: menu.service.retry()
                    }
                    Column {
                        width: parent.width
                        spacing: 14
                        visible: menu.service.displays.length > 0
                        Row {
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: [
                                    {
                                        mode: "extend",
                                        title: "Extend",
                                        description: "Separate desktops"
                                    },
                                    {
                                        mode: "mirror",
                                        title: "Mirror",
                                        description: "Same content"
                                    }
                                ]
                                delegate: Button {
                                    id: modeButton
                                    required property var modelData
                                    width: (parent.width - 8) / 2
                                    height: 57
                                    enabled: menu.editable && (modelData.mode === "extend" || menu.service.displays.length > 1)
                                    hoverEnabled: true
                                    opacity: enabled ? 1 : 0.5
                                    Accessible.name: modelData.title
                                    contentItem: Column {
                                        spacing: 4
                                        Label {
                                            text: modeButton.modelData.title
                                            color: menu.draft.mode === modeButton.modelData.mode ? "#D6B48C" : "#F8F9F9"
                                            font.weight: Font.Medium
                                        }
                                        Label {
                                            text: modeButton.modelData.description
                                            font.pixelSize: 11
                                        }
                                    }
                                    leftPadding: 12
                                    rightPadding: 12
                                    topPadding: 10
                                    bottomPadding: 10
                                    background: Rectangle {
                                        radius: 8
                                        color: modeButton.hovered ? "#35312C" : "#242424"
                                        border {
                                            width: 1
                                            color: menu.draft.mode === modeButton.modelData.mode ? "#D6B48C" : "#383838"
                                        }
                                    }
                                    onClicked: {
                                        const next = Model.copy(menu.draft);
                                        next.mode = modelData.mode;
                                        if (next.mode === "mirror")
                                            next.primary = menu.service.displays.find(d => d.internal)?.id || next.primary;
                                        else if (menu.draft.mode === "mirror") {
                                            menu.edit(Model.arrange(menu.service.displays, next, "horizontal", false));
                                            return;
                                        }
                                        menu.edit(next);
                                    }
                                }
                            }
                        }
                        DisplayDiagram {
                            width: parent.width
                            displays: menu.service.displays
                            layout: menu.draft
                            selected: menu.selected
                            fontFamily: menu.theme.fontFamily
                            active: menu.opened
                            previews: menu.previews
                            editable: menu.editable
                            onSelectedDisplay: id => menu.selected = id
                            onMoved: (id, x, y) => menu.edit(Model.snap(menu.service.displays, menu.draft, id, x, y))
                        }
                        Row {
                            width: parent.width
                            spacing: 6
                            Action {
                                text: "Side by side"
                                enabled: menu.editable && menu.draft.mode === "extend"
                                onClicked: menu.edit(Model.arrange(menu.service.displays, menu.draft, "horizontal", false))
                            }
                            Action {
                                text: "Stack"
                                enabled: menu.editable && menu.draft.mode === "extend"
                                onClicked: menu.edit(Model.arrange(menu.service.displays, menu.draft, "vertical", false))
                            }
                            Action {
                                text: "Reverse"
                                enabled: menu.editable && menu.draft.mode === "extend"
                                onClicked: menu.edit(Model.arrange(menu.service.displays, menu.draft, Model.dimensions(menu.service.displays, menu.draft).height > Model.dimensions(menu.service.displays, menu.draft).width ? "vertical" : "horizontal", true))
                            }
                            Item {
                                width: Math.max(0, parent.width - 293)
                                height: 1
                            }
                        }
                        CheckBox {
                            id: livePreviews
                            text: "Live previews"
                            checked: menu.previews
                            onToggled: menu.previews = checked
                            implicitHeight: 28
                            spacing: 8
                            font {
                                family: menu.theme.fontFamily
                                pixelSize: 12
                            }
                            indicator: Rectangle {
                                x: livePreviews.leftPadding
                                y: (livePreviews.height - height) / 2
                                width: 18
                                height: 18
                                radius: 5
                                color: livePreviews.checked ? "#D6B48C" : "#242424"
                                border {
                                    width: 1
                                    color: livePreviews.visualFocus ? "#F8F9F9" : livePreviews.checked ? "#D6B48C" : "#555555"
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    visible: livePreviews.checked
                                    color: "#242424"
                                    font.pixelSize: 13
                                }
                            }
                            contentItem: Text {
                                text: livePreviews.text
                                color: "#B8B8B8"
                                font: livePreviews.font
                                leftPadding: livePreviews.indicator.width + livePreviews.spacing
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: selectedContent.implicitHeight + 24
                            radius: 10
                            color: "#242424"
                            Column {
                                id: selectedContent
                                x: 12
                                y: 12
                                width: parent.width - 24
                                spacing: 7
                                Row {
                                    width: parent.width
                                    spacing: 8
                                    Label {
                                        width: parent.width - makeMain.width - 8
                                        text: (menu.service.displays.findIndex(d => d.id === menu.selected) + 1) + " · " + (menu.selectedDisplay?.label || "Display")
                                        color: "#F8F9F9"
                                        font.weight: Font.Medium
                                    }
                                    Action {
                                        id: makeMain
                                        text: menu.draft.primary === menu.selected ? "Main display" : "Make main"
                                        accent: menu.draft.primary === menu.selected
                                        opacity: menu.draft.primary === menu.selected || enabled ? 1 : 0.45
                                        enabled: menu.editable && menu.draft.mode === "extend" && menu.draft.primary !== menu.selected
                                        onClicked: {
                                            const next = Model.copy(menu.draft);
                                            next.primary = menu.selected;
                                            menu.edit(next);
                                        }
                                    }
                                }
                                Label {
                                    text: (menu.selectedDisplay?.pixelWidth || 0) + " × " + (menu.selectedDisplay?.pixelHeight || 0) + " · " + Math.round(menu.selectedDisplay?.rate || 0) + " Hz · " + Math.round((menu.selectedDisplay?.scale || 1) * 100) + "% scale"
                                }
                                Label {
                                    width: parent.width
                                    text: menu.draft.mode === "mirror" ? "Mirrors the laptop when one is connected. Different screen shapes may leave borders." : "Workspaces follow the main display. Those placed on other screens stay there. Empty displays use a free workspace from 1–10."
                                    font.pixelSize: 11
                                }
                            }
                        }
                        Row {
                            spacing: 8
                            visible: menu.dirty && !menu.service.pending
                            Action {
                                text: menu.service.busy ? "Applying…" : "Apply layout"
                                objectName: "applyDisplayLayout"
                                accent: true
                                enabled: menu.editable
                                onClicked: menu.applyDraft()
                            }
                            Action {
                                text: "Reset"
                                enabled: menu.editable
                                onClicked: menu.resetDraft()
                            }
                        }
                    }
                    Label {
                        width: parent.width
                        visible: menu.service.message.length > 0 && !menu.service.pending && !menu.dirty
                        text: menu.service.message
                        color: "#A9C7BC"
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#383838"
                    }
                    Controls.Disclosure {
                        width: parent.width
                        text: "When connecting a display"
                        fontFamily: menu.theme.fontFamily
                        checked: menu.connectionExpanded
                        onClicked: {
                            menu.connectionExpanded = checked;
                            menu.settle();
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: 8
                        visible: menu.connectionExpanded
                        Controls.RadioHeader {
                            width: parent.width
                            title: "External display becomes main"
                            icon: "󰍹"
                            subtitle: menu.service.externalMain ? "Move your main workspaces to an external screen." : "Keep the laptop as your main display."
                            fontFamily: menu.theme.fontFamily
                            checked: menu.service.externalMain
                            available: menu.editable
                            onToggled: menu.service.send("preference", {
                                externalMain: !menu.service.externalMain
                            })
                        }
                        Label {
                            width: parent.width
                            text: "Applies the next time you connect a display. Confirmed arrangements are remembered for each set of screens."
                            font.pixelSize: 11
                        }
                    }
                    Controls.Disclosure {
                        width: parent.width
                        text: "Saved layouts"
                        fontFamily: menu.theme.fontFamily
                        checked: menu.layoutsExpanded
                        onClicked: {
                            menu.layoutsExpanded = checked;
                            menu.settle();
                        }
                    }
                    Column {
                        width: parent.width
                        spacing: 9
                        visible: menu.layoutsExpanded
                        Label {
                            width: parent.width
                            visible: !menu.service.profiles.length
                            text: "Save setups such as Desk or Presentation."
                        }
                        Repeater {
                            model: menu.service.profiles
                            delegate: Row {
                                required property var modelData
                                width: parent.width
                                spacing: 7
                                Action {
                                    width: parent.width - removeLayout.width - updateLayout.width - 14
                                    text: parent.modelData.name
                                    enabled: menu.editable && parent.modelData.available
                                    onClicked: menu.loadProfile(parent.modelData)
                                }
                                Action {
                                    id: updateLayout
                                    text: "Update"
                                    enabled: menu.editable && !menu.dirty && parent.modelData.available
                                    onClicked: menu.service.send("update", {
                                        id: parent.modelData.id
                                    })
                                }
                                Action {
                                    id: removeLayout
                                    text: menu.removeId === parent.modelData.id ? "Confirm" : "Remove"
                                    enabled: menu.editable
                                    onClicked: {
                                        if (menu.removeId === parent.modelData.id) {
                                            menu.service.send("delete", {
                                                id: parent.modelData.id
                                            });
                                            menu.removeId = "";
                                        } else
                                            menu.removeId = parent.modelData.id;
                                    }
                                }
                            }
                        }
                        Row {
                            width: parent.width
                            spacing: 8
                            TextField {
                                id: layoutName
                                width: parent.width - saveLayout.width - 8
                                height: 34
                                placeholderText: "Layout name"
                                maximumLength: 60
                                selectByMouse: true
                                color: "#F8F9F9"
                                placeholderTextColor: "#888888"
                                font {
                                    family: menu.theme.fontFamily
                                    pixelSize: 12
                                }
                                leftPadding: 9
                                rightPadding: 9
                                background: Rectangle {
                                    radius: 7
                                    color: "#242424"
                                    border {
                                        width: 1
                                        color: layoutName.activeFocus ? "#D6B48C" : "#454545"
                                    }
                                }
                                onAccepted: if (saveLayout.enabled)
                                    saveLayout.clicked()
                            }
                            Action {
                                id: saveLayout
                                text: "Save current"
                                enabled: menu.editable && !menu.dirty && layoutName.text.trim().length > 0
                                onClicked: {
                                    menu.service.send("save", {
                                        name: layoutName.text.trim()
                                    });
                                    layoutName.clear();
                                }
                            }
                        }
                        Label {
                            width: parent.width
                            text: menu.dirty ? "Apply your changes before saving this layout." : "Save and Update include workspace placements. Changes you make afterward won’t overwrite a named layout."
                            font.pixelSize: 11
                        }
                        Label {
                            width: parent.width
                            text: "Layouts recognize the same monitor on another port, or a matching model when there’s only one clear match."
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
