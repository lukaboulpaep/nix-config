//@ pragma ShellId luka-shell

import Quickshell
import QtQuick

ShellRoot {
  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        required property var modelData

        screen: modelData
        color: "transparent"
        implicitHeight: 38

        anchors {
          left: true
          right: true
          top: true
        }

        margins {
          left: 10
          right: 10
          top: 8
        }

        Rectangle {
          anchors.fill: parent
          color: "#d9111318"
          radius: 14

          Text {
            anchors.centerIn: parent
            color: "#f4f1ec"
            font.family: "Inter"
            font.pixelSize: 13
            text: Qt.formatDateTime(clock.date, "HH:mm")

            SystemClock {
              id: clock
              precision: SystemClock.Minutes
            }
          }
        }
      }
    }
  }
}
