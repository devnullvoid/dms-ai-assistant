import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import "./markdown2html.js" as Markdown2Html
import qs.Widgets

Item {
    id: root
    property string role: "assistant"
    property string text: ""
    property string status: "ok" // ok|streaming|error
    property bool useMonospace: false

    readonly property bool isUser: role === "user"
    readonly property real bubbleMaxWidth: isUser ? Math.max(240, Math.floor(width * 0.82)) : width
    readonly property color userBubbleFill: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)
    readonly property color userBubbleBorder: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)
    readonly property color assistantBubbleFill: Theme.surfaceContainer
    readonly property color assistantBubbleBorder: Theme.outline

    readonly property var themeColors: ({
        "codeBg": Theme.surfaceContainerHigh,
        "blockquoteBg": Theme.withAlpha(Theme.surfaceContainerHighest, 0.5),
        "blockquoteBorder": Theme.outlineVariant,
        "inlineCodeBg": Theme.withAlpha(Theme.onSurface, 0.1)
    })

    readonly property bool useMarkdownRendering: !isUser && status !== "streaming"
    readonly property string renderedHtml: Markdown2Html.markdownToHtml(root.text, themeColors)

    width: parent ? parent.width : implicitWidth
    implicitHeight: bubble.implicitHeight

    Rectangle {
        id: bubble
        width: Math.min(root.bubbleMaxWidth, root.width)
        x: root.isUser ? (root.width - width) : 0
        radius: Theme.cornerRadius
        color: root.isUser ? root.userBubbleFill : root.assistantBubbleFill
        border.color: status === "error" ? Theme.error : (root.isUser ? root.userBubbleBorder : root.assistantBubbleBorder)
        border.width: 1

        implicitHeight: contentColumn.implicitHeight + Theme.spacingM * 2
        height: implicitHeight

        Behavior on x {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: contentColumn
            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingS

            RowLayout {
                id: headerRow
                width: parent.width
                spacing: Theme.spacingXS

                // assistant: [icon][chip][spacer][copy]
                // user:      [spacer][chip][icon]
                Item { Layout.fillWidth: root.isUser }

                Rectangle {
                    radius: Theme.cornerRadius
                    color: root.isUser ? Theme.withAlpha(Theme.primary, 0.14) : Theme.surfaceVariant
                    Layout.preferredHeight: Theme.fontSizeSmall * 1.6
                    Layout.preferredWidth: headerText.implicitWidth + Theme.spacingS * 2

                    StyledText {
                        id: headerText
                        anchors.centerIn: parent
                        text: root.isUser ? I18n.tr("You") : I18n.tr("Assistant")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: root.isUser ? Theme.primary : Theme.surfaceVariantText
                    }
                }

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: root.isUser ? Theme.withAlpha(Theme.primary, 0.20) : Theme.surfaceVariant
                    border.width: 1
                    border.color: root.isUser ? Theme.withAlpha(Theme.primary, 0.35) : Theme.surfaceVariantAlpha

                    DankIcon {
                        anchors.centerIn: parent
                        name: root.isUser ? "person" : "smart_toy"
                        size: 14
                        color: root.isUser ? Theme.primary : Theme.surfaceVariantText
                    }
                }

                Item { Layout.fillWidth: !root.isUser }

                DankActionButton {
                    visible: !root.isUser && root.status === "ok"
                    iconName: "content_copy"
                    buttonSize: 24
                    iconSize: 14
                    backgroundColor: "transparent"
                    iconColor: Theme.surfaceVariantText
                    tooltipText: I18n.tr("Copy")
                    onClicked: {
                        Quickshell.execDetached(["wl-copy", root.text]);
                    }
                }
            }

            Item {
                width: 1
                height: Theme.spacingS
            }

            StyledText {
                visible: root.status === "error"
                text: I18n.tr("Error")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.error
                width: parent.width
            }

            TextArea {
                text: root.useMarkdownRendering ? root.renderedHtml : root.text
                textFormat: root.useMarkdownRendering ? Text.RichText : Text.PlainText
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeMedium
                font.family: root.useMonospace ? Theme.monoFontFamily : Theme.fontFamily
                color: status === "error" ? Theme.error : Theme.surfaceText
                width: parent.width

                readOnly: true
                selectByMouse: true
                selectionColor: Theme.primary
                selectedTextColor: Theme.onPrimary
                background: null
                leftPadding: 4
                rightPadding: 4

                onLinkActivated: link => {
                    Qt.openUrlExternally(link);
                }

                hoverEnabled: true
            }

            Rectangle {
                visible: status === "streaming"
                radius: Theme.cornerRadius
                color: Theme.surfaceVariant
                height: Theme.fontSizeSmall * 1.6
                width: streamingText.implicitWidth + Theme.spacingS * 2
                x: root.isUser ? (parent.width - width) : 0

                StyledText {
                    id: streamingText
                    anchors.centerIn: parent
                    text: I18n.tr("Streaming…")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
