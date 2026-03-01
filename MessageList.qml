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
    signal copySuccess()

    Component.onCompleted: console.log("[MessageList] ready")

    // Scroll to bottom when a new message is appended.
    Connections {
        target: root.messages
        function onCountChanged() {
            if (root.stickToBottom) {
                Qt.callLater(() => listView.positionViewAtEnd());
            }
        }
    }

    // Scroll to bottom when streaming ends so the fully-rendered markdown
    // (which can be significantly taller than the streaming plain text) is visible.
    Connections {
        target: root.aiService
        function onIsStreamingChanged() {
            if (root.aiService && !root.aiService.isStreaming) {
                scrollSettleTimer.restart();
            }
        }
    }

    // Give the markdown layout two frames to settle before scrolling.
    Timer {
        id: scrollSettleTimer
        interval: 32
        repeat: false
        onTriggered: listView.positionViewAtEnd()
    }

    ListView {
        id: listView
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        model: root.messages
        spacing: Theme.spacingM
        clip: true
        ScrollBar.vertical: ScrollBar { }

        onContentYChanged: {
            // Use a small tolerance to avoid stickToBottom flipping to false
            // while positionViewAtEnd() is mid-flight during a height update.
            const maxY = Math.max(0, listView.contentHeight - listView.height);
            root.stickToBottom = listView.contentY >= maxY - 20;
        }

        onContentHeightChanged: {
            if (root.stickToBottom) {
                Qt.callLater(() => listView.positionViewAtEnd());
            }
        }

        onModelChanged: {
            Qt.callLater(() => {
                root.stickToBottom = true;
                listView.positionViewAtEnd();
            });
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
