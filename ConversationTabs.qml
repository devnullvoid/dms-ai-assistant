import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root
    property var conversations: []
    property string activeId: ""
    property string editingId: ""
    signal selected(string conversationId)
    signal renamed(string conversationId, string title)
    signal closeRequested(string conversationId)
    signal newRequested()
    implicitHeight: 36
    readonly property bool overflowing: conversations.length * 128 + Math.max(0, conversations.length - 1) * Theme.spacingXS
        > width - newButton.width - Theme.spacingXS

    function finishRename(id, title) {
        if (editingId !== id)
            return;
        editingId = "";
        if (title.trim())
            renamed(id, title.trim());
    }

    DankActionButton {
        id: scrollLeftButton
        objectName: "scrollConversationTabsLeft"
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.overflowing
        width: visible ? buttonSize : 0
        enabled: tabScroll.contentX > 0.5
        iconName: "chevron_left"
        tooltipText: I18n.tr("Scroll tabs left")
        buttonSize: 32
        onClicked: tabScroll.scrollTabs(-1)
    }

    Flickable {
        id: tabScroll
        objectName: "conversationTabScroll"
        anchors.left: scrollLeftButton.right
        anchors.leftMargin: root.overflowing ? Theme.spacingXS : 0
        anchors.right: scrollRightButton.left
        anchors.rightMargin: root.overflowing ? Theme.spacingXS : 0
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        contentWidth: tabRow.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        function scrollTabs(direction) {
            cancelFlick();
            contentX = Math.max(0, Math.min(contentWidth - width,
                contentX + direction * Math.max(root.tabWidth, width * 0.8)));
        }

        function revealActive() {
            const index = root.conversations.findIndex(tab => tab.id === root.activeId);
            if (index < 0)
                return;
            const left = index * (root.tabWidth + Theme.spacingXS);
            if (left < contentX)
                contentX = left;
            else if (left + root.tabWidth > contentX + width)
                contentX = Math.max(0, left + root.tabWidth - width);
        }
        onWidthChanged: Qt.callLater(revealActive)

        Row {
            id: tabRow
            spacing: Theme.spacingXS

            Repeater {
                model: root.conversations
                delegate: Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool active: root.activeId === modelData.id
                    readonly property bool editing: root.editingId === modelData.id
                    objectName: "conversationTab-" + modelData.id
                    width: root.tabWidth
                    height: 32
                    radius: Theme.cornerRadius
                    color: active ? Theme.surfaceVariant : (tabMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                    border.width: active ? 0 : 1
                    border.color: Theme.outlineMedium
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.title

                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent
                        enabled: !tab.editing
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selected(tab.modelData.id)
                        onDoubleClicked: {
                            root.selected(tab.modelData.id);
                            root.editingId = tab.modelData.id;
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: closeButton.left
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !tab.editing
                        text: tab.modelData.title === "New chat" ? I18n.tr("New chat") : tab.modelData.title
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        elide: Text.ElideMiddle
                    }

                    TextInput {
                        id: renameField
                        objectName: "conversationRename-" + tab.modelData.id
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tab.editing
                        enabled: tab.editing
                        color: Theme.primary
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.onPrimary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        maximumLength: 80
                        selectByMouse: true
                        clip: true
                        onAccepted: root.finishRename(tab.modelData.id, text)
                        onEditingFinished: root.finishRename(tab.modelData.id, text)
                        Keys.onEscapePressed: root.editingId = ""
                        onVisibleChanged: {
                            if (visible) {
                                text = tab.modelData.title;
                                Qt.callLater(() => {
                                    if (visible) {
                                        forceActiveFocus();
                                        selectAll();
                                    }
                                });
                            }
                        }
                    }

                    Item {
                        id: closeButton
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.conversations.length > 1 ? 24 : Theme.spacingS
                        height: 24
                        visible: root.conversations.length > 1 && !tab.editing
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.tr("Close conversation")
                        DankIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 14
                            color: Theme.surfaceText
                        }
                        MouseArea {
                            objectName: "conversationClose-" + tab.modelData.id
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested(tab.modelData.id)
                        }
                    }
                }
            }
        }
    }

    readonly property real tabWidth: Math.max(128, Math.min(260,
        (tabScroll.width - Math.max(0, conversations.length - 1) * Theme.spacingXS) / Math.max(1, conversations.length)))
    onActiveIdChanged: {
        editingId = "";
        Qt.callLater(tabScroll.revealActive);
    }
    onConversationsChanged: Qt.callLater(tabScroll.revealActive)

    DankActionButton {
        id: scrollRightButton
        objectName: "scrollConversationTabsRight"
        anchors.right: newButton.left
        anchors.rightMargin: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter
        visible: root.overflowing
        width: visible ? buttonSize : 0
        enabled: tabScroll.contentX < Math.max(0, tabScroll.contentWidth - tabScroll.width) - 0.5
        iconName: "chevron_right"
        tooltipText: I18n.tr("Scroll tabs right")
        buttonSize: 32
        onClicked: tabScroll.scrollTabs(1)
    }

    DankActionButton {
        id: newButton
        objectName: "newConversationButton"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconName: "add"
        tooltipText: I18n.tr("New chat")
        buttonSize: 32
        onClicked: root.newRequested()
    }
}
