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
        model = PluginService.loadPluginData(pluginId, "model", "gpt-5.2")
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

                    // Provider Configuration Card
                    Rectangle {
                        width: parent.width
                        height: providerContent.height + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                        border.width: 1

                        Column {
                            id: providerContent
                            width: parent.width - Theme.spacingL * 2
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            // Header
                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: "settings"
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Provider Configuration")
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: Theme.spacingS

                                // Provider Dropdown
                                StyledText {
                                    text: I18n.tr("Provider")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                DankDropdown {
                                    width: parent.width
                                    options: ["openai", "anthropic", "gemini", "custom"]
                                    currentValue: root.provider
                                    onValueChanged: value => save("provider", value)
                                }

                                // Base URL
                                StyledText {
                                    text: I18n.tr("Base URL")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                DankTextField {
                                    width: parent.width
                                    text: root.baseUrl
                                    placeholderText: "https://api.openai.com"
                                    onEditingFinished: save("baseUrl", text.trim())
                                }

                                // Model
                                StyledText {
                                    text: I18n.tr("Model")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                DankTextField {
                                    width: parent.width
                                    text: root.model
                                    placeholderText: "gpt-5.2"
                                    onEditingFinished: save("model", text.trim())
                                }
                            }
                        }
                    }

                    // API Authentication Card
                    Rectangle {
                        width: parent.width
                        height: authContent.height + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                        border.width: 1

                        Column {
                            id: authContent
                            width: parent.width - Theme.spacingL * 2
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            // Header
                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: "vpn_key"
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("API Authentication")
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Column {
                                width: parent.width
                                spacing: Theme.spacingS

                                // API Key
                                StyledText {
                                    text: I18n.tr("API Key")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                DankTextField {
                                    width: parent.width
                                    text: root.saveApiKey ? root.apiKey : aiService.sessionApiKey
                                    echoMode: TextInput.Password
                                    placeholderText: I18n.tr("Enter API key")
                                    leftIconName: root.saveApiKey ? "lock" : "vpn_key"
                                    onEditingFinished: {
                                        if (root.saveApiKey) {
                                            save("apiKey", text.trim())
                                        } else {
                                            aiService.sessionApiKey = text.trim()
                                        }
                                    }
                                }

                                // Env Var
                                StyledText {
                                    text: I18n.tr("API Key Env Var")
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                DankTextField {
                                    width: parent.width
                                    text: root.apiKeyEnvVar
                                    placeholderText: I18n.tr("e.g. OPENAI_API_KEY")
                                    leftIconName: "terminal"
                                    onEditingFinished: save("apiKeyEnvVar", text.trim())
                                }

                                // Remember API Key Toggle
                                Item {
                                    width: parent.width
                                    height: Theme.spacingS
                                }

                                RowLayout {
                                    width: parent.width
                                    spacing: Theme.spacingM
                                    StyledText {
                                        text: I18n.tr("Remember API Key")
                                        Layout.fillWidth: true
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
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
                        }
                    }

                    // Temperature Card
                    Rectangle {
                        width: parent.width
                        height: tempContent.height + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                        border.width: 1

                        Column {
                            id: tempContent
                            width: parent.width - Theme.spacingL * 2
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: "thermostat"
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXS
                                    width: parent.width - parent.spacing - Theme.iconSize

                                    StyledText {
                                        text: I18n.tr("Temperature: %1").arg(root.temperature.toFixed(1))
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: I18n.tr("Controls randomness (0 = focused, 2 = creative)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }
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
                        }
                    }

                    // Max Tokens Card
                    Rectangle {
                        width: parent.width
                        height: tokensContent.height + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                        border.width: 1

                        Column {
                            id: tokensContent
                            width: parent.width - Theme.spacingL * 2
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: "data_usage"
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingXS
                                    width: parent.width - parent.spacing - Theme.iconSize

                                    StyledText {
                                        text: I18n.tr("Max Tokens: %1").arg(root.maxTokens)
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: I18n.tr("Maximum response length")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }
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
                    }

                    // Display Options Card
                    Rectangle {
                        width: parent.width
                        height: displayContent.height + Theme.spacingL * 2
                        radius: Theme.cornerRadius
                        color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
                        border.width: 1

                        Column {
                            id: displayContent
                            width: parent.width - Theme.spacingL * 2
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            // Header
                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                DankIcon {
                                    name: "code"
                                    size: Theme.iconSize
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: I18n.tr("Display Options")
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Medium
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Item {
                                width: parent.width
                                height: Math.max(monoToggle.height, descColumn.height)

                                Column {
                                    id: descColumn
                                    anchors.left: parent.left
                                    anchors.right: monoToggle.left
                                    anchors.rightMargin: Theme.spacingM
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: I18n.tr("Monospace Font")
                                        font.pixelSize: Theme.fontSizeMedium
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: I18n.tr("Use monospace font for AI replies (better for code)")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                        wrapMode: Text.WordWrap
                                        width: parent.width
                                    }
                                }

                                DankToggle {
                                    id: monoToggle
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
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
}
