pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

PopupWindow {
    id: preview
    property bool opened: false
    property Item target: null
    property var entry: null
    required property string fontFamily
    property url wallpaperSource: ""
    readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === entry?.id) ?? null
    readonly property var monitor: workspace?.monitor ?? Hyprland.monitors.values.find(m => m.name === entry?.monitor) ?? null
    readonly property var output: monitor?.lastIpcObject ?? ({})
    readonly property real outputScale: output.scale || 1
    readonly property bool rotated: (output.transform || 0) % 2 !== 0
    readonly property real desktopWidth: Math.max(1, (rotated ? output.height : output.width) / outputScale || 1920)
    readonly property real desktopHeight: Math.max(1, (rotated ? output.width : output.height) / outputScale || 1080)
    readonly property var windows: workspace?.toplevels.values.filter(w => !w.lastIpcObject.hidden) ?? []
    // Initialize the Wayland handles used by HyprlandToplevel.wayland.
    readonly property var managedWindows: ToplevelManager.toplevels.values
    readonly property string titles: windows.map(w => w.title || w.lastIpcObject.class || "Application").join(" · ")

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 8
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY
    implicitWidth: 352
    implicitHeight: 16 + 28 + 18 + 12 + Math.min(220, 308 * desktopHeight / desktopWidth) + (windows.length ? 28 : 0)
    color: "transparent"
    grabFocus: false
    mask: Region {}
    visible: opened && target !== null && entry !== null
    onOpenedChanged: if (opened)
        Hyprland.refreshToplevels()
    onEntryChanged: if (opened)
        Hyprland.refreshToplevels()

    // Destroy captures as soon as the pointer leaves; no background recording.
    Loader {
        anchors.fill: parent
        active: preview.visible
        sourceComponent: Item {
            RectangularShadow {
                anchors.fill: card
                radius: 12
                blur: 16
                offset.y: 3
                color: "#60000000"
            }
            Rectangle {
                id: card
                anchors {
                    fill: parent
                    margins: 8
                }
                radius: 12
                color: "#1D1D1D"
                border {
                    width: 1
                    color: "#383838"
                }
                Row {
                    id: heading
                    x: 14
                    y: 14
                    width: parent.width - 28
                    spacing: 8
                    Text {
                        width: parent.width - count.width - parent.spacing
                        text: "Workspace " + (preview.entry?.label || "")
                        color: "#F8F9F9"
                        elide: Text.ElideRight
                        font {
                            family: preview.fontFamily
                            pixelSize: 13
                            weight: Font.Medium
                        }
                    }
                    Text {
                        id: count
                        text: preview.windows.length ? preview.windows.length + (preview.windows.length === 1 ? " window" : " windows") : "Empty"
                        color: "#B8B8B8"
                        font {
                            family: preview.fontFamily
                            pixelSize: 11
                        }
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Rectangle {
                    id: desktop
                    x: 14
                    y: 44
                    width: parent.width - 28
                    height: Math.min(220, width * preview.desktopHeight / preview.desktopWidth)
                    radius: 7
                    color: "#242424"
                    clip: true
                    readonly property real factor: Math.min(width / preview.desktopWidth, height / preview.desktopHeight)
                    Image {
                        anchors.fill: parent
                        source: preview.wallpaperSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: preview.windows.length ? "#16000000" : "#80000000"
                    }
                    Repeater {
                        model: preview.windows
                        delegate: Rectangle {
                            id: tile
                            required property var modelData
                            readonly property var geometry: modelData.lastIpcObject
                            x: (desktop.width - preview.desktopWidth * desktop.factor) / 2 + ((geometry.at?.[0] || 0) - (preview.output.x || 0)) * desktop.factor
                            y: (desktop.height - preview.desktopHeight * desktop.factor) / 2 + ((geometry.at?.[1] || 0) - (preview.output.y || 0)) * desktop.factor
                            width: Math.max(1, (geometry.size?.[0] || preview.desktopWidth) * desktop.factor)
                            height: Math.max(1, (geometry.size?.[1] || preview.desktopHeight) * desktop.factor)
                            z: (geometry.floating ? 10000 : 0) + 1000 - (geometry.focusHistoryID || 0)
                            color: "#302C28"
                            radius: 3
                            clip: true
                            ScreencopyView {
                                id: capture
                                objectName: "workspaceWindowCapture"
                                anchors.fill: parent
                                captureSource: preview.visible ? tile.modelData.wayland : null
                                live: preview.visible
                                paintCursor: false
                                constraintSize: Qt.size(640, 400)
                            }
                            Text {
                                anchors {
                                    fill: parent
                                    margins: 6
                                }
                                visible: !capture.hasContent
                                text: tile.modelData.title || tile.geometry.class || "Application"
                                color: "#D6B48C"
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                font {
                                    family: preview.fontFamily
                                    pixelSize: 11
                                }
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                radius: 3
                                border {
                                    width: 1
                                    color: "#606A655E"
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !preview.windows.length
                        text: "No windows here"
                        color: "#F8F9F9"
                        font {
                            family: preview.fontFamily
                            pixelSize: 12
                        }
                    }
                }
                Text {
                    x: 14
                    y: desktop.y + desktop.height + 10
                    width: parent.width - 28
                    visible: preview.windows.length > 0
                    text: preview.titles
                    elide: Text.ElideRight
                    color: "#B8B8B8"
                    font {
                        family: preview.fontFamily
                        pixelSize: 11
                    }
                }
            }
        }
    }
}
