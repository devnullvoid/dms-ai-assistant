import QtQuick
import QtQuick.Controls
import qs.Common

Item {
    id: root
    clip: true
    property var messages: null // expects a ListModel
    property bool stickToBottom: true
    property bool useMonospace: false

    Component.onCompleted: console.log("[MessageList] ready")

    Connections {
        target: root.messages
        function onCountChanged() {
            if (root.stickToBottom) {
                Qt.callLater(() => listView.positionViewAtEnd());
            }
        }
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
            root.stickToBottom = listView.atYEnd;
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
                role: model.role
                text: model.content
                status: model.status
                useMonospace: root.useMonospace

                Component.onCompleted: {
                    console.log("[MessageList] add", role, text ? text.slice(0, 40) : "")
                }
            }
        }
    }
}
