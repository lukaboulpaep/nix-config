pragma ComponentBehavior: Bound
import QtQuick
import "Stats.js" as Stats

Column {
    id: details
    required property var stats
    required property var theme
    spacing: 12

    component Label: Text {
        textFormat: Text.PlainText
        color: "#B8B8B8"
        font {
            family: details.theme.fontFamily
            pixelSize: 12
        }
        wrapMode: Text.WordWrap
    }
    component Card: Rectangle {
        default property alias content: content.data
        implicitHeight: content.implicitHeight + 28
        radius: 12
        color: "#242424"
        Column {
            id: content
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 14
        }
    }
    component SectionTitle: Label {
        font {
            pixelSize: 10
            letterSpacing: 1.2
            weight: Font.Medium
        }
        color: "#A0A0A0"
    }
    component Divider: Rectangle {
        height: 1
        color: "#363636"
    }
    component ValueRow: Item {
        id: row
        required property string label
        required property string value
        property color valueColor: "#F8F9F9"
        implicitHeight: Math.max(caption.implicitHeight, reading.implicitHeight)
        Label {
            id: caption
            width: parent.width * 0.38
            text: row.label
        }
        Label {
            id: reading
            anchors.right: parent.right
            width: parent.width * 0.6
            text: row.value
            horizontalAlignment: Text.AlignRight
            color: row.valueColor
        }
    }
    component Metric: Column {
        id: metric
        required property string label
        required property string value
        property color accent: "#F8F9F9"
        spacing: 5
        Label {
            width: parent.width
            text: metric.label
            font.pixelSize: 11
        }
        Label {
            width: parent.width
            text: metric.value
            color: metric.accent
            font.pixelSize: 20
        }
    }

    Card {
        width: parent.width
        Column {
            width: parent.width
            spacing: 7
            SectionTitle {
                text: "PROCESSOR"
            }
            Label {
                width: parent.width
                text: details.stats.cpuModel.replace(/\(R\)|\(TM\)/gi, "").replace(/\s+/g, " ").trim() || "Processor"
                color: "#F8F9F9"
                font {
                    pixelSize: 18
                    weight: Font.Medium
                }
            }
        }
        Row {
            width: parent.width
            spacing: 16
            Metric {
                width: (parent.width - 16) / 2
                label: "Processor threads"
                value: String(details.stats.cores.length)
            }
            Metric {
                width: (parent.width - 16) / 2
                label: "Average clock"
                value: details.stats.frequency > 0 ? details.stats.frequency.toFixed(2) + " GHz" : "—"
                accent: "#D6B48C"
            }
        }
        Divider {
            width: parent.width
        }
        Column {
            width: parent.width
            spacing: 12
            Label {
                text: "Thread activity"
                color: "#F8F9F9"
                font.weight: Font.Medium
            }
            Grid {
                id: threads
                width: parent.width
                columns: width >= 340 ? 4 : width >= 240 ? 3 : 2
                columnSpacing: 12
                rowSpacing: 12
                Repeater {
                    model: details.stats.cores.length
                    Item {
                        id: thread
                        required property int index
                        readonly property var modelData: details.stats.cores[index] ?? ({
                                name: "",
                                value: -1
                            })
                        width: (threads.width - (threads.columns - 1) * threads.columnSpacing) / threads.columns
                        height: 28
                        Accessible.role: Accessible.StaticText
                        Accessible.name: modelData.name + ": " + (modelData.value < 0 ? "unavailable" : Math.round(modelData.value) + " percent")
                        Label {
                            text: thread.modelData.name.replace(/^cpu/, "CPU ")
                            font.pixelSize: 10
                            color: "#A0A0A0"
                        }
                        Label {
                            anchors.right: parent.right
                            text: thread.modelData.value < 0 ? "—" : Math.round(thread.modelData.value) + "%"
                            font.pixelSize: 10
                            color: "#F8F9F9"
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 4
                            radius: 2
                            color: "#3A3631"
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(100, thread.modelData.value)) / 100
                                height: parent.height
                                radius: 2
                                color: "#D6B48C"
                            }
                        }
                    }
                }
            }
            Label {
                width: parent.width
                text: "Live activity across the CPU’s logical processors."
                color: "#888888"
                font.pixelSize: 11
            }
        }
        Divider {
            width: parent.width
            visible: details.stats.fanSpeed >= 0
        }
        ValueRow {
            width: parent.width
            visible: details.stats.fanSpeed >= 0
            label: "Fan speed"
            value: details.stats.fanSpeed === 0 ? "Stopped · 0 RPM" : details.stats.fanSpeed + " RPM"
        }
    }
    Card {
        width: parent.width
        Row {
            width: parent.width
            SectionTitle {
                width: parent.width / 2
                text: "MEMORY"
            }
            Label {
                width: parent.width / 2
                horizontalAlignment: Text.AlignRight
                text: details.stats.memoryTotal > 0 ? Stats.bytes(details.stats.memoryTotal) + " usable" : "—"
                font.pixelSize: 11
            }
        }
        Row {
            width: parent.width
            spacing: 16
            Metric {
                width: (parent.width - 16) / 2
                label: "In use"
                value: Stats.bytes(details.stats.memoryUsed)
                accent: "#A9C7BC"
            }
            Metric {
                width: (parent.width - 16) / 2
                label: "Available"
                value: Stats.bytes(Math.max(0, details.stats.memoryTotal - details.stats.memoryUsed))
            }
        }
        Rectangle {
            width: parent.width
            height: 5
            radius: 3
            color: "#343D39"
            Rectangle {
                width: parent.width * (details.stats.memoryTotal > 0 ? Math.min(1, details.stats.memoryUsed / details.stats.memoryTotal) : 0)
                height: parent.height
                radius: 3
                color: "#A9C7BC"
            }
        }
        Label {
            width: parent.width
            text: "Available memory includes cache Linux can reclaim."
            color: "#888888"
            font.pixelSize: 11
        }
        Divider {
            width: parent.width
        }
        ValueRow {
            width: parent.width
            label: "Swap"
            value: details.stats.swapTotal > 0 ? Stats.bytes(details.stats.swapUsed) + " / " + Stats.bytes(details.stats.swapTotal) : "Not configured"
            valueColor: details.stats.swapTotal > 0 ? "#F8F9F9" : "#B8B8B8"
        }
    }
    Card {
        width: parent.width
        visible: details.stats.gpu >= 0
        SectionTitle {
            text: "GRAPHICS"
        }
        ValueRow {
            width: parent.width
            label: "Activity"
            value: details.stats.gpu + "%"
            valueColor: "#D6B48C"
        }
    }
    Card {
        width: parent.width
        Column {
            width: parent.width
            spacing: 7
            SectionTitle {
                text: "SYSTEM"
            }
            Label {
                width: parent.width
                text: details.stats.operatingSystem
                color: "#F8F9F9"
                font {
                    pixelSize: 15
                    weight: Font.Medium
                }
            }
        }
        Divider {
            width: parent.width
        }
        ValueRow {
            width: parent.width
            label: "Kernel"
            value: details.stats.kernel || "—"
        }
    }
}
