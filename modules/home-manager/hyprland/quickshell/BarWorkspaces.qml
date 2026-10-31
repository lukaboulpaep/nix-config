import QtQuick
import QtQuick.Controls
import Quickshell.Hyprland
import "WorkspaceModel.js" as Model

Row {
    id: workspaces
    required property color foreground
    required property string fontFamily
    required property int fontSize
    required property string monitorName
    required property var entries
    property url wallpaperSource: ""
    spacing: 2

    function previewFor(button, entry) {
        hidePreview.stop();
        preview.target = button;
        preview.entry = entry;
        if (!preview.opened)
            showPreview.restart();
    }
    function leavePreview(button) {
        if (preview.target !== button)
            return;
        showPreview.stop();
        hidePreview.restart();
    }
    function closePreview() {
        showPreview.stop();
        hidePreview.stop();
        preview.opened = false;
    }
    Timer {
        id: showPreview
        interval: 280
        onTriggered: if (preview.target?.hovered)
            preview.opened = true
    }
    Timer {
        id: hidePreview
        interval: 80
        onTriggered: preview.opened = false
    }
    WorkspacePreview {
        id: preview
        objectName: "workspacePreview"
        fontFamily: workspaces.fontFamily
        wallpaperSource: workspaces.wallpaperSource
    }

    Repeater {
        model: workspaces.entries

        Button {
            id: workspaceButton
            required property var modelData
            objectName: "workspace-" + modelData.key
            readonly property bool current: Hyprland.focusedWorkspace?.id === modelData.id
            readonly property bool visibleHere: modelData.current && modelData.monitor === workspaces.monitorName
            readonly property int windowCount: modelData.windowCount
            readonly property bool numbered: current || windowCount > 0 || modelData.id < 0
            readonly property string description: "Workspace " + modelData.label + (current ? ", focused" : "") + (visibleHere ? ", visible on this display" : "") + ", " + windowCount + (windowCount === 1 ? " application" : " applications") + " · " + modelData.monitor

            width: Math.max(20, Math.min(96, workspaceLabel.implicitWidth + 8))
            height: 24
            padding: 0
            hoverEnabled: true
            Accessible.name: description
            onHoveredChanged: if (hovered)
                workspaces.previewFor(workspaceButton, modelData)
            else
                workspaces.leavePreview(workspaceButton)
            onPressed: workspaces.closePreview()

            background: Rectangle {
                radius: 7
                color: workspaceButton.current ? workspaces.foreground : workspaceButton.hovered || workspaceButton.visualFocus ? "#20FFFFFF" : "transparent"
            }
            contentItem: Item {
                Text {
                    id: workspaceLabel
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 8)
                    elide: Text.ElideRight
                    visible: workspaceButton.numbered
                    text: workspaceButton.modelData.label
                    color: workspaceButton.current ? "#1D1D1D" : workspaces.foreground
                    font.family: workspaces.fontFamily
                    font.pixelSize: workspaces.fontSize
                    font.weight: workspaceButton.current ? Font.DemiBold : Font.Normal
                }
                Rectangle {
                    anchors.centerIn: parent
                    visible: !workspaceButton.numbered
                    width: 4
                    height: 4
                    radius: 2
                    color: workspaces.foreground
                    opacity: workspaceButton.hovered ? 0.8 : 0.35
                }
            }

            onClicked: Hyprland.dispatch(Model.focusRequest(workspaceButton.modelData))
        }
    }
}
