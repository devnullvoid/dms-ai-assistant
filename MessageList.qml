import QtQuick
import QtQuick.Controls
import qs.Common

Item {
    id: root
    clip: true
    property var messages: null // expects a ListModel
    property var aiService: null
    property bool stickToBottom: true
    property bool useMonospace: false
    property bool autoScrolling: false
    signal copySuccess()

    Component.onCompleted: console.log("[MessageList] ready")

    function nearBottom() {
        // Variable-height ListView delegates can move originY away from zero.
        const bottom = listView.originY + Math.max(0, listView.contentHeight - listView.height);
        return listView.contentY >= bottom - 20;
    }

    function pauseFollowing() {
        stickToBottom = false;
        followTimer.stop();
        scrollSettleTimer.stop();
    }

    function updateUserScroll() {
        if (autoScrolling)
            return;
        stickToBottom = nearBottom();
        if (stickToBottom)
            requestFollow();
    }

    function requestFollow() {
        if (stickToBottom)
            followTimer.restart();
    }

    function followIfWanted() {
        // Re-check at execution time: the user may have scrolled since this
        // was scheduled, or may still be holding the scrollbar/scrolling.
        if (!stickToBottom || listView.moving || scrollBar.pressed || wheelObserver.active)
            return;
        autoScrolling = true;
        listView.positionViewAtEnd();
        autoScrolling = false;
    }

    Timer {
        id: followTimer
        interval: 0
        onTriggered: root.followIfWanted()
    }

    // Scroll to bottom when a new message is appended.
    Connections {
        target: root.messages
        function onCountChanged() {
            root.requestFollow();
        }
    }

    // Scroll to bottom when streaming ends so the fully-rendered markdown
    // (which can be significantly taller than the streaming plain text) is visible.
    Connections {
        target: root.aiService
        function onIsStreamingChanged() {
            if (root.aiService && !root.aiService.isStreaming && root.stickToBottom) {
                scrollSettleTimer.restart();
            }
        }
    }

    // Give the markdown layout two frames to settle before scrolling.
    Timer {
        id: scrollSettleTimer
        interval: 32
        repeat: false
        onTriggered: root.followIfWanted()
    }

    ListView {
        id: listView
        objectName: "messageListView"
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        model: root.messages
        spacing: Theme.spacingM
        clip: true
        ScrollBar.vertical: ScrollBar {
            id: scrollBar
            objectName: "messageScrollBar"
            onPressedChanged: {
                if (pressed)
                    root.pauseFollowing();
                else
                    root.updateUserScroll();
            }
        }

        WheelHandler {
            id: wheelObserver
            target: null
            blocking: false
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: {
                root.pauseFollowing();
                // Observe the event without stealing it from the ListView.
                Qt.callLater(root.updateUserScroll);
            }
            onActiveChanged: {
                if (!active)
                    root.updateUserScroll();
            }
        }

        onMovementStarted: root.pauseFollowing()
        onMovementEnded: root.updateUserScroll()

        onContentYChanged: {
            // Layout/estimated-height changes must not re-enable following.
            if (moving || scrollBar.pressed || wheelObserver.active)
                root.updateUserScroll();
        }

        onContentHeightChanged: root.requestFollow()
        onHeightChanged: root.requestFollow()

        onModelChanged: {
            root.stickToBottom = true;
            root.requestFollow();
        }

        delegate: Item {
            id: wrapper
            width: listView.width

            readonly property string previousRole: (index > 0 && root.messages) ? (root.messages.get(index - 1).role || "") : ""
            readonly property bool roleChanged: previousRole.length > 0 && previousRole !== (model.role || "")
            readonly property int topGap: roleChanged ? Theme.spacingM : 0

            implicitHeight: bubble.implicitHeight + topGap

            MessageBubble {
                id: bubble
                width: listView.width
                y: wrapper.topGap
                messageId: model.id
                role: model.role
                text: model.content
                status: model.status
                useMonospace: root.useMonospace

                onCopySuccess: root.copySuccess()

                Component.onCompleted: {
                    console.log("[MessageList] add", role, text ? text.slice(0, 40) : "")
                }

                onRegenerateRequested: messageId => {
                    if (!aiService || !aiService.regenerateFromMessageId)
                        return;
                    console.log("[MessageList] regenerate requested for message id", messageId);
                    aiService.regenerateFromMessageId(messageId);
                }
            }
        }
    }
}
