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
    property var providers: ({})
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

    function defaultsForProvider(id) {
        switch (id) {
        case "anthropic":
            return {
                baseUrl: "https://api.anthropic.com",
                model: "claude-sonnet-4-5",
                apiKey: "",
                saveApiKey: false,
                apiKeyEnvVar: "",
                temperature: 0.7,
                maxTokens: 4096,
                timeout: 30
            };
        case "gemini":
            return {
                baseUrl: "https://generativelanguage.googleapis.com",
                model: "gemini-3-flash-preview",
                apiKey: "",
                saveApiKey: false,
                apiKeyEnvVar: "",
                temperature: 0.7,
                maxTokens: 4096,
                timeout: 30
            };
        case "custom":
            return {
                baseUrl: "https://api.openai.com",
                model: "gpt-5.2",
                apiKey: "",
                saveApiKey: false,
                apiKeyEnvVar: "",
                temperature: 0.7,
                maxTokens: 4096,
                timeout: 30
            };
        default:
            return {
                baseUrl: "https://api.openai.com",
                model: "gpt-5.2",
                apiKey: "",
                saveApiKey: false,
                apiKeyEnvVar: "",
                temperature: 0.7,
                maxTokens: 4096,
                timeout: 30
            };
        }
    }

    function normalizedProfile(id, raw) {
        const d = defaultsForProvider(id)
        const p = raw || {}
        return {
            baseUrl: String(p.baseUrl || d.baseUrl).trim(),
            model: String(p.model || d.model).trim(),
            apiKey: String(p.apiKey || "").trim(),
            saveApiKey: !!p.saveApiKey,
            apiKeyEnvVar: String(p.apiKeyEnvVar || "").trim(),
            temperature: (typeof p.temperature === "number") ? p.temperature : d.temperature,
            maxTokens: (typeof p.maxTokens === "number") ? p.maxTokens : d.maxTokens,
            timeout: (typeof p.timeout === "number") ? p.timeout : d.timeout
        }
    }

    function mergedProviders(rawProviders) {
        const next = {
            openai: normalizedProfile("openai", null),
            anthropic: normalizedProfile("anthropic", null),
            gemini: normalizedProfile("gemini", null),
            custom: normalizedProfile("custom", null)
        }
        if (!rawProviders || typeof rawProviders !== "object")
            return next

        const ids = ["openai", "anthropic", "gemini", "custom"]
        for (let i = 0; i < ids.length; i++) {
            const id = ids[i]
            if (rawProviders[id] && typeof rawProviders[id] === "object") {
                next[id] = normalizedProfile(id, rawProviders[id])
            }
        }
        return next
    }

    function saveProviders(nextProviders) {
        providers = nextProviders
        PluginService.savePluginData(pluginId, "providers", nextProviders)
    }

    function applyActiveProfile() {
        const active = providers[provider] || normalizedProfile(provider, null)
        baseUrl = active.baseUrl
        model = active.model
        apiKey = active.apiKey
        saveApiKey = active.saveApiKey
        apiKeyEnvVar = active.apiKeyEnvVar
        temperature = active.temperature
        maxTokens = active.maxTokens
    }

    function setProvider(providerId) {
        provider = providerId
        const active = providers[provider] || normalizedProfile(provider, null)
        applyActiveProfile()
        save("provider", provider)
        save("baseUrl", active.baseUrl)
        save("model", active.model)
        save("apiKey", active.apiKey)
        save("saveApiKey", active.saveApiKey)
        save("apiKeyEnvVar", active.apiKeyEnvVar)
        save("temperature", active.temperature)
        save("maxTokens", active.maxTokens)
    }

    function saveActiveField(key, value) {
        root[key] = value
        const nextProviders = Object.assign({}, providers)
        const current = Object.assign({}, nextProviders[provider] || normalizedProfile(provider, null))
        current[key] = value
        nextProviders[provider] = normalizedProfile(provider, current)
        saveProviders(nextProviders)

        // Keep active-provider legacy keys in sync for compatibility and easier debugging.
        if (["baseUrl", "model", "apiKey", "saveApiKey", "apiKeyEnvVar", "temperature", "maxTokens"].includes(key)) {
            save(key, nextProviders[provider][key])
        }
    }

    function load() {
        const selectedProvider = String(PluginService.loadPluginData(pluginId, "provider", "openai")).trim() || "openai"
        provider = ["openai", "anthropic", "gemini", "custom"].includes(selectedProvider) ? selectedProvider : "openai"

        const rawProviders = PluginService.loadPluginData(pluginId, "providers", null)
        let nextProviders = mergedProviders(rawProviders)

        if (!rawProviders || typeof rawProviders !== "object") {
            const legacyProfile = {
                baseUrl: PluginService.loadPluginData(pluginId, "baseUrl", defaultsForProvider(provider).baseUrl),
                model: PluginService.loadPluginData(pluginId, "model", defaultsForProvider(provider).model),
                apiKey: PluginService.loadPluginData(pluginId, "apiKey", ""),
                saveApiKey: PluginService.loadPluginData(pluginId, "saveApiKey", false),
                apiKeyEnvVar: PluginService.loadPluginData(pluginId, "apiKeyEnvVar", ""),
                temperature: PluginService.loadPluginData(pluginId, "temperature", 0.7),
                maxTokens: PluginService.loadPluginData(pluginId, "maxTokens", 4096),
                timeout: PluginService.loadPluginData(pluginId, "timeout", 30)
            }
            nextProviders[provider] = normalizedProfile(provider, legacyProfile)
            saveProviders(nextProviders)
        } else {
            providers = nextProviders
        }

        applyActiveProfile()
        useMonospace = PluginService.loadPluginData(pluginId, "useMonospace", false)
    }

    function focusApiKeyField() {
        if (apiKeyField) {
            apiKeyField.forceActiveFocus()
        }
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
                                    onValueChanged: value => setProvider(value)
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
                                    onEditingFinished: saveActiveField("baseUrl", text.trim())
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
                                    onEditingFinished: saveActiveField("model", text.trim())
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
                                    id: apiKeyField
                                    width: parent.width
                                    text: root.saveApiKey ? root.apiKey : aiService.sessionApiKey
                                    echoMode: TextInput.Password
                                    placeholderText: I18n.tr("Enter API key")
                                    leftIconName: root.saveApiKey ? "lock" : "vpn_key"
                                    onEditingFinished: {
                                        if (root.saveApiKey) {
                                            saveActiveField("apiKey", text.trim())
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
                                    onEditingFinished: saveActiveField("apiKeyEnvVar", text.trim())
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
                                            saveActiveField("saveApiKey", checked)
                                            if (checked && aiService.sessionApiKey) {
                                                saveActiveField("apiKey", aiService.sessionApiKey)
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
                                onSliderValueChanged: newValue => saveActiveField("temperature", newValue / 10)
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
                                onSliderValueChanged: newValue => saveActiveField("maxTokens", newValue)
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
