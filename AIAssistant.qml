import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    Component.onCompleted: console.info("[AIAssistant UI Plugin] ready, service:", aiService)
    onAiServiceChanged: console.info("[AIAssistant UI Plugin] service changed:", aiService)

    required property var aiService
    property bool showSettingsMenu: false
    readonly property real panelTransparency: SettingsData.popupTransparency
    readonly property bool hasApiKey: !!(aiService && aiService.resolveApiKey && aiService.resolveApiKey().length > 0)
    signal hideRequested

    function sendCurrentMessage() {
        if (!composer.text || composer.text.trim().length === 0)
            return;
        if (!aiService) {
            console.warn("[AIAssistant UI] service unavailable");
            return;
        }
        console.log("[AIAssistant UI] sendCurrentMessage");
        aiService.sendMessage(composer.text.trim());
        composer.text = "";
    }

    function getLastAssistantText() {
        const svc = aiService;
        if (!svc || !svc.messagesModel)
            return "";
        const model = svc.messagesModel;
        for (let i = model.count - 1; i >= 0; i--) {
            const m = model.get(i);
            if (m.role === "assistant" && m.status === "ok")
                return m.content || "";
        }
        return "";
    }

    function hasAssistantError() {
        const svc = aiService;
        if (!svc || !svc.messagesModel)
            return false;
        const model = svc.messagesModel;
        for (let i = model.count - 1; i >= 0; i--) {
            const m = model.get(i);
            if (m.role === "assistant" && m.status === "error")
                return true;
        }
        return false;
    }

    function copyLastAssistant() {
        const text = getLastAssistantText();
        if (!text)
            return;
        Quickshell.execDetached(["wl-copy", text]);
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingM

        RowLayout {
            id: headerRow
            width: parent.width
            spacing: Theme.spacingS

            Rectangle {
                radius: Theme.cornerRadius
                color: Theme.surfaceVariant
                height: Theme.fontSizeSmall * 1.6
                Layout.preferredWidth: providerLabel.implicitWidth + Theme.spacingM
                Layout.alignment: Qt.AlignVCenter

                StyledText {
                    id: providerLabel
                    anchors.centerIn: parent
                    text: (aiService.provider || "openai").toUpperCase()
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }
            }

            Rectangle {
                width: 10
                height: 10
                radius: 5
                color: aiService.isOnline ? Theme.success : Theme.surfaceVariantText
                Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            DankActionButton {
                iconName: "settings"
                tooltipText: showSettingsMenu ? I18n.tr("Hide settings") : I18n.tr("Settings")
                onClicked: showSettingsMenu = !showSettingsMenu
            }

            DankActionButton {
                iconName: "delete"
                tooltipText: I18n.tr("Clear history")
                enabled: (aiService.messageCount ?? 0) > 0 && !(aiService.isStreaming ?? false)
                onClicked: aiService.clearHistory(true)
            }

            DankActionButton {
                id: overflowButton
                iconName: "more_vert"
                tooltipText: I18n.tr("More")
                onClicked: overflowMenu.popup(overflowButton, -overflowMenu.width + overflowButton.width, overflowButton.height + Theme.spacingXS)
            }

            Menu {
                id: overflowMenu
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                background: Rectangle {
                    color: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)
                    radius: Theme.cornerRadius
                    border.width: 0
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.12)
                }

                MenuItem {
                    text: showSettingsMenu ? I18n.tr("Hide settings") : I18n.tr("Settings")
                    onTriggered: showSettingsMenu = !showSettingsMenu
                }

                MenuSeparator {}

                MenuItem {
                    text: I18n.tr("Copy last reply")
                    enabled: getLastAssistantText().length > 0
                    onTriggered: copyLastAssistant()
                }

                MenuItem {
                    text: I18n.tr("Retry")
                    enabled: hasAssistantError() && !(aiService.isStreaming ?? false)
                    onTriggered: aiService.retryLast()
                }

                MenuItem {
                    text: I18n.tr("Close")
                    onTriggered: root.hideRequested()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: parent.height - headerRow.height - composerRow.height - Theme.spacingM * 3
            radius: Theme.cornerRadius
            color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, root.panelTransparency)
            border.color: Theme.surfaceVariantAlpha
            border.width: 1

            MessageList {
                id: list
                anchors.fill: parent
                messages: aiService.messagesModel
                useMonospace: aiService.useMonospace
            }

            StyledText {
                anchors.centerIn: parent
                visible: (aiService.messageCount ?? 0) === 0
                text: {
                    if (!hasApiKey) return I18n.tr("Configure a provider and API key in Settings to start chatting.");

                    const provider = aiService.provider ?? "openai";
                    const baseUrl = aiService.baseUrl ?? "";
                    const isRemote = provider !== "custom" || (!baseUrl.includes("localhost") && !baseUrl.includes("127.0.0.1"));

                    if (isRemote) {
                        return I18n.tr("Note: Your messages will be sent to a remote provider (%1).\nDo not send sensitive information.").arg(provider.toUpperCase());
                    }
                    return I18n.tr("Ready to chat locally.");
                }
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceTextMedium
                wrapMode: Text.Wrap
                width: parent.width * 0.8
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Row {
            id: composerRow
            width: parent.width
            height: 120
            spacing: Theme.spacingM

            Rectangle {
                id: composerContainer
                width: parent.width - actionButtons.width - Theme.spacingM
                height: 120
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                border.color: composer.activeFocus ? Theme.primary : Theme.outlineMedium
                border.width: composer.activeFocus ? 2 : 1

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                Behavior on border.width {
                    NumberAnimation {
                        duration: Theme.shortDuration
                        easing.type: Theme.standardEasing
                    }
                }

                ScrollView {
                    id: scrollView
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    clip: true
                    padding: 0
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    TextArea {
                        id: composer
                        implicitWidth: scrollView.availableWidth
                        wrapMode: TextArea.Wrap
                        background: Rectangle { color: "transparent" }
                        font.pixelSize: Theme.fontSizeMedium
                        font.family: Theme.fontFamily
                        font.weight: Theme.fontWeight
                        color: Theme.surfaceText
                        Material.accent: Theme.primary
                        padding: 0
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0

                        Keys.onReleased: event => {
                            if (event.key === Qt.Key_Escape) {
                                hideRequested();
                                event.accepted = true;
                            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Return) {
                                sendCurrentMessage();
                                event.accepted = true;
                            }
                        }
                    }
                }

                StyledText {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    text: I18n.tr("Ask anything…")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.outlineButton
                    verticalAlignment: Text.AlignTop
                    visible: composer.text.length === 0
                    wrapMode: Text.Wrap
                }
            }

            Column {
                id: actionButtons
                spacing: Theme.spacingS
                width: 100

                DankButton {
                    text: I18n.tr("Send")
                    iconName: "send"
                    enabled: composer.text && composer.text.trim().length > 0
                    width: parent.width
                    onClicked: sendCurrentMessage()
                }

                DankButton {
                    text: I18n.tr("Stop")
                    iconName: "stop"
                    enabled: aiService.isStreaming
                    backgroundColor: Theme.error
                    textColor: Theme.errorText
                    width: parent.width
                    onClicked: aiService.cancel()
                }
            }
        }
    }

    AIAssistantSettings {
        id: settingsPanel
        anchors.fill: parent
        isVisible: showSettingsMenu
        onCloseRequested: showSettingsMenu = false
        pluginId: "aiAssistant"
        aiService: aiService
    }
}
