import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services

Item {
    id: root
    property bool isVisible: false
    signal closeRequested

    required property var aiService
    property string pluginId: "aiAssistant"

    // Local state for persistent settings
    property string provider: "openai"
    property string baseUrl: ""
    property string model: ""
    property string apiKey: ""
    property bool saveApiKey: false
    property string apiKeyEnvVar: ""
    property real temperature: 0.7
    property int maxTokens: 4096
    property bool useMonospace: false

    function save(key, value) {
        PluginService.savePluginData(pluginId, key, value)
        root[key] = value
    }

    function load() {
        provider = PluginService.loadPluginData(pluginId, "provider", "openai")
        baseUrl = PluginService.loadPluginData(pluginId, "baseUrl", "https://api.openai.com")
        model = PluginService.loadPluginData(pluginId, "model", "gpt-4.1-mini")
        apiKey = PluginService.loadPluginData(pluginId, "apiKey", "")
        saveApiKey = PluginService.loadPluginData(pluginId, "saveApiKey", false)
        apiKeyEnvVar = PluginService.loadPluginData(pluginId, "apiKeyEnvVar", "")
        temperature = PluginService.loadPluginData(pluginId, "temperature", 0.7)
        maxTokens = PluginService.loadPluginData(pluginId, "maxTokens", 4096)
        useMonospace = PluginService.loadPluginData(pluginId, "useMonospace", false)
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(pId) {
            if (pId === pluginId) load();
        }
    }

    Component.onCompleted: load()
    onIsVisibleChanged: if (isVisible) load()

    visible: isVisible

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.98)
        radius: Theme.cornerRadius
        border.color: Theme.surfaceVariantAlpha
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingL

                StyledText {
                    text: I18n.tr("AI Assistant Settings")
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                DankButton {
                    text: I18n.tr("Close")
                    iconName: "close"
                    onClicked: closeRequested()
                }
            }

            DankFlickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: settingsColumn.implicitHeight + Theme.spacingXL
                contentWidth: width

                Column {
                    id: settingsColumn
                    width: Math.min(550, parent.width - Theme.spacingL * 2)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingL

                    // Provider Section
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Provider Configuration")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.primary
                        }

                        // Provider Dropdown
                        StyledText { text: I18n.tr("Provider"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        DankDropdown {
                            width: parent.width
                            options: ["openai", "anthropic", "gemini", "custom"]
                            currentValue: root.provider
                            onValueChanged: value => save("provider", value)
                        }

                        // Base URL
                        StyledText { text: I18n.tr("Base URL"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        DankTextField {
                            width: parent.width
                            text: root.baseUrl
                            placeholderText: "https://api.openai.com"
                            onEditingFinished: save("baseUrl", text.trim())
                        }

                        // Model
                        StyledText { text: I18n.tr("Model"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        DankTextField {
                            width: parent.width
                            text: root.model
                            placeholderText: "gpt-4-mini"
                            onEditingFinished: save("model", text.trim())
                        }
                    }

                    // Auth Section
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("API Authentication")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.primary
                        }

                        // API Key
                        StyledText { text: I18n.tr("API Key"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        DankTextField {
                            width: parent.width
                            // Logic: If saveApiKey is true, show saved key (root.apiKey). If false, show session key (aiService.sessionApiKey)
                            text: root.saveApiKey ? root.apiKey : aiService.sessionApiKey
                            echoMode: TextInput.Password
                            placeholderText: I18n.tr("Enter API key")
                            leftIconName: root.saveApiKey ? "lock" : "vpn_key"
                            onEditingFinished: {
                                if (root.saveApiKey) {
                                    save("apiKey", text.trim())
                                } else {
                                    aiService.sessionApiKey = text.trim() // In memory
                                }
                            }
                        }

                        // Env Var
                        StyledText { text: I18n.tr("API Key Env Var"); font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                        DankTextField {
                            width: parent.width
                            text: root.apiKeyEnvVar
                            placeholderText: I18n.tr("e.g. OPENAI_API_KEY")
                            leftIconName: "terminal"
                            onEditingFinished: save("apiKeyEnvVar", text.trim())
                        }

                        // Save Toggle
                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingM
                            StyledText {
                                text: I18n.tr("Remember API Key")
                                Layout.fillWidth: true
                                color: Theme.surfaceText
                            }
                            DankToggle {
                                checked: root.saveApiKey
                                onToggled: checked => {
                                    save("saveApiKey", checked)
                                    if (checked && aiService.sessionApiKey) {
                                        save("apiKey", aiService.sessionApiKey)
                                    }
                                }
                            }
                        }
                    }

                    // Parameters Section
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Model Parameters")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.primary
                        }

                        // Temperature
                        RowLayout {
                            width: parent.width
                            StyledText { text: I18n.tr("Temperature"); color: Theme.surfaceVariantText }
                            Item { Layout.fillWidth: true }
                            StyledText { text: root.temperature.toFixed(1); color: Theme.primary }
                        }
                        DankSlider {
                            width: parent.width
                            height: 32
                            minimum: 0
                            maximum: 20
                            value: Math.round(root.temperature * 10)
                            showValue: false
                            onSliderValueChanged: newValue => save("temperature", newValue / 10)
                        }

                        // Max Tokens
                        RowLayout {
                            width: parent.width
                            StyledText { text: I18n.tr("Max Tokens"); color: Theme.surfaceVariantText }
                            Item { Layout.fillWidth: true }
                            StyledText { text: root.maxTokens; color: Theme.primary }
                        }
                        DankSlider {
                            width: parent.width
                            height: 32
                            minimum: 128
                            maximum: 32768
                            step: 256
                            value: root.maxTokens
                            showValue: false
                            onSliderValueChanged: newValue => save("maxTokens", newValue)
                        }
                    }

                    // Display Section
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Display Options")
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.primary
                        }

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingM
                            StyledText {
                                text: I18n.tr("Monospace Font")
                                Layout.fillWidth: true
                                color: Theme.surfaceText
                            }
                            DankToggle {
                                checked: root.useMonospace
                                onToggled: checked => save("useMonospace", checked)
                            }
                        }
                    }
                }
            }
        }
    }
}
