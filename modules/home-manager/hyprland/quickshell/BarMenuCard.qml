import QtQuick
import QtQuick.Window

// Keep the frame still; only the page inside it moves during a panel switch.
Rectangle {
    id: card
    required property var menuWindow
    default property alias content: page.data
    readonly property Item pageItem: page
    property real pageOffset: 0
    property var previousFrame: null
    property real previousWidth: 0
    property real previousHeight: 0
    property bool awaitingFrame: false
    function prepareSwitch(frame, width, height) {
        slide.stop();
        previousFrame = frame;
        previousWidth = width;
        previousHeight = height;
        pageOffset = menuWindow.switchDirection * card.width;
        awaitingFrame = true;
        // Begin moving immediately; waiting for presentation adds a stationary
        // first frame (and another round trip through the compositor).
        slide.start();
    }
    function releasePrevious() {
        if (menuWindow.handoffFrom)
            menuWindow.handoffFrom.held = false;
        menuWindow.handoffFrom = null;
    }
    clip: true
    data: [
        MouseArea {
            anchors.fill: parent
        },
        Item {
            id: page
            anchors.fill: parent
            transform: Translate {
                x: card.pageOffset
            }
        },
        Image {
            // Retain the outgoing page in memory until it has slid away.
            source: card.previousFrame ? card.previousFrame.url : ""
            visible: card.previousFrame !== null
            x: card.pageOffset - card.menuWindow.switchDirection * card.width
            width: card.previousWidth
            height: card.previousHeight
        },
        NumberAnimation {
            id: slide
            target: card
            property: "pageOffset"
            to: 0
            duration: 220
            easing.type: Easing.OutCubic
            onFinished: {
                card.previousFrame = null;
                card.menuWindow.switching = false;
            }
        },
        Connections {
            target: card.Window.window
            function onFrameSwapped() {
                if (!card.awaitingFrame || !card.menuWindow.opened)
                    return;
                card.awaitingFrame = false;
                card.releasePrevious();
            }
        },
        Connections {
            target: card.menuWindow
            function onOpenedChanged() {
                if (card.menuWindow.opened && card.awaitingFrame)
                    return;
                slide.stop();
                card.awaitingFrame = false;
                card.previousFrame = null;
                card.pageOffset = 0;
                card.releasePrevious();
            }
        }
    ]
}
