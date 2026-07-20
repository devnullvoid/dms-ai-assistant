import QtQuick
import QtCore
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "./AIApiAdapters.js" as AIApiAdapters

Item {
    id: root

    property string pluginId: "aiAssistant"

    Component.onCompleted: {
        console.info("[AIAssistantService Plugin] ready");
        loadSettings();
        mkdirProcess.running = true;
    }

    readonly property string baseDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericStateLocation) + "/DankMaterialShell/plugins/aiAssistant")
    readonly property string sessionPath: baseDir + "/session.json"
    property bool sessionLoaded: false
    property string providerConfigHash: ""
    property var sessionsByConfig: ({})
    property bool suppressConfigChange: false
    property int maxStoredMessages: 50

    property ListModel messagesModel: ListModel {}
    property int messageCount: messagesModel.count
    property bool isStreaming: false
    property bool isOnline: false
    property string activeStreamId: ""
    property real streamStartedAtMs: 0
    property string lastUserText: ""
    property int lastHttpStatus: 0

    // Settings
    property var providers: ({})
    property string provider: "openai"
    property string baseUrl: "https://api.openai.com"
    property string model: "gpt-5.2"
    property real temperature: 0.7
    property int maxTokens: 4096
    property int timeout: 30
    property string apiKey: ""
    property bool saveApiKey: false
    property string sessionApiKey: "" // In-memory key
    property string apiKeyEnvVar: ""
    property bool useMonospace: false
    property string inceptionReasoningEffort: "medium"
    property bool inceptionReasoningSummary: true
    property bool inceptionReasoningSummaryWait: false
    property bool geminiWebSearch: false
    property var availableModels: []
    property var availableModelDetails: []
    property bool modelsLoading: false
    property string modelsError: ""
    property string modelFetchOutput: ""
    property string modelDiscoveryConfig: ""
    property string modelFetchProvider: ""
    property string modelFetchBaseUrl: ""
    property string modelFetchCredential: ""
    property bool pendingModelRefresh: false
    readonly property var selectableModels: (availableModels || []).slice()
    readonly property bool currentModelDiscovered: !!model && (availableModels || []).indexOf(model) >= 0

    readonly property bool debugEnabled: (Quickshell.env("DMS_LOG_LEVEL") || "").toLowerCase() === "debug"

    onProviderChanged: handleConfigChanged()
    onBaseUrlChanged: handleConfigChanged()
    onSessionApiKeyChanged: refreshAvailableModels(true)

    function defaultsForProvider(id) {
        switch (id) {
        case "inception":
            return {
                baseUrl: "https://api.inceptionlabs.ai/v1",
                model: "mercury-2",
                apiKey: "",
                saveApiKey: false,
                apiKeyEnvVar: "",
                temperature: 0.75,
                maxTokens: 8192,
                timeout: 30,
                inceptionReasoningEffort: "medium",
                inceptionReasoningSummary: true,
                inceptionReasoningSummaryWait: false
            };
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
                timeout: 30,
                geminiWebSearch: false
            };
        case "ollama":
            return {
                baseUrl: "http://localhost:11434",
                model: "",
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
        const defaults = defaultsForProvider(id);
        const p = raw || {};
        const profile = {
            baseUrl: String(p.baseUrl || defaults.baseUrl).trim(),
            model: String(p.model || defaults.model).trim(),
            apiKey: String(p.apiKey || "").trim(),
            saveApiKey: !!p.saveApiKey,
            apiKeyEnvVar: String(p.apiKeyEnvVar || "").trim(),
            temperature: (typeof p.temperature === "number") ? p.temperature : defaults.temperature,
            maxTokens: (typeof p.maxTokens === "number") ? p.maxTokens : defaults.maxTokens,
            timeout: (typeof p.timeout === "number") ? p.timeout : defaults.timeout
        };
        if (id === "inception") {
            const efforts = ["instant", "low", "medium", "high"];
            let eff = String(p.inceptionReasoningEffort || defaults.inceptionReasoningEffort || "medium").toLowerCase();
            profile.inceptionReasoningEffort = efforts.indexOf(eff) >= 0 ? eff : "medium";
            profile.inceptionReasoningSummary = (typeof p.inceptionReasoningSummary === "boolean") ? p.inceptionReasoningSummary : (defaults.inceptionReasoningSummary !== false);
            profile.inceptionReasoningSummaryWait = !!p.inceptionReasoningSummaryWait;
        } else if (id === "gemini") {
            profile.geminiWebSearch = (typeof p.geminiWebSearch === "boolean") ? p.geminiWebSearch : !!defaults.geminiWebSearch;
        }
        return profile;
    }

    function mergedProviders(rawProviders) {
        const base = {
            openai: normalizedProfile("openai", null),
            anthropic: normalizedProfile("anthropic", null),
            gemini: normalizedProfile("gemini", null),
            inception: normalizedProfile("inception", null),
            ollama: normalizedProfile("ollama", null),
            custom: normalizedProfile("custom", null)
        };

        if (!rawProviders || typeof rawProviders !== "object")
            return base;

        const ids = ["openai", "anthropic", "gemini", "inception", "ollama", "custom"];
        for (let i = 0; i < ids.length; i++) {
            const id = ids[i];
            if (rawProviders[id] && typeof rawProviders[id] === "object") {
                base[id] = normalizedProfile(id, rawProviders[id]);
            }
        }
        return base;
    }

    function syncLegacySnapshot(activeProfile) {
        PluginService.savePluginData(pluginId, "provider", provider)
        PluginService.savePluginData(pluginId, "baseUrl", activeProfile.baseUrl)
        PluginService.savePluginData(pluginId, "model", activeProfile.model)
        PluginService.savePluginData(pluginId, "apiKey", activeProfile.apiKey)
        PluginService.savePluginData(pluginId, "saveApiKey", activeProfile.saveApiKey)
        PluginService.savePluginData(pluginId, "apiKeyEnvVar", activeProfile.apiKeyEnvVar)
        PluginService.savePluginData(pluginId, "temperature", activeProfile.temperature)
        PluginService.savePluginData(pluginId, "maxTokens", activeProfile.maxTokens)
        PluginService.savePluginData(pluginId, "timeout", activeProfile.timeout)
        PluginService.savePluginData(pluginId, "geminiWebSearch", !!activeProfile.geminiWebSearch)
    }

    function loadSettings() {
        suppressConfigChange = true
        const selectedProvider = String(PluginService.loadPluginData(pluginId, "provider", "openai")).trim() || "openai"
        const providerId = ["openai", "anthropic", "gemini", "inception", "ollama", "custom"].includes(selectedProvider) ? selectedProvider : "openai"
        const rawProviders = PluginService.loadPluginData(pluginId, "providers", null)
        let nextProviders = mergedProviders(rawProviders)

        if (!rawProviders || typeof rawProviders !== "object") {
            const legacyProfile = {
                baseUrl: String(PluginService.loadPluginData(pluginId, "baseUrl", defaultsForProvider(providerId).baseUrl)).trim(),
                model: String(PluginService.loadPluginData(pluginId, "model", defaultsForProvider(providerId).model)).trim(),
                temperature: PluginService.loadPluginData(pluginId, "temperature", 0.7),
                maxTokens: PluginService.loadPluginData(pluginId, "maxTokens", 4096),
                timeout: PluginService.loadPluginData(pluginId, "timeout", 30),
                geminiWebSearch: PluginService.loadPluginData(pluginId, "geminiWebSearch", false),
                apiKey: String(PluginService.loadPluginData(pluginId, "apiKey", "")).trim(),
                saveApiKey: PluginService.loadPluginData(pluginId, "saveApiKey", false),
                apiKeyEnvVar: String(PluginService.loadPluginData(pluginId, "apiKeyEnvVar", "")).trim()
            }
            nextProviders[providerId] = normalizedProfile(providerId, legacyProfile)
            PluginService.savePluginData(pluginId, "providers", nextProviders)
            syncLegacySnapshot(nextProviders[providerId])
        }

        providers = nextProviders
        provider = providerId

        const active = providers[provider] || normalizedProfile(provider, null)
        baseUrl = active.baseUrl
        model = active.model
        temperature = active.temperature
        maxTokens = active.maxTokens
        timeout = active.timeout
        apiKey = active.apiKey
        saveApiKey = active.saveApiKey
        apiKeyEnvVar = active.apiKeyEnvVar
        if (provider === "inception") {
            inceptionReasoningEffort = active.inceptionReasoningEffort || "medium";
            inceptionReasoningSummary = active.inceptionReasoningSummary !== false;
            inceptionReasoningSummaryWait = !!active.inceptionReasoningSummaryWait;
        }
        geminiWebSearch = !!active.geminiWebSearch
        useMonospace = PluginService.loadPluginData(pluginId, "useMonospace", false)
        suppressConfigChange = false
        refreshAvailableModels(false)

        const currentHash = computeConfigHash();
        if (providerConfigHash !== currentHash)
            switchConfigHistory(currentHash)
    }

    Connections {
        target: PluginService
        function onPluginDataChanged(pId) {
            if (pId !== root.pluginId) return;
            loadSettings();
        }
    }

    Process {
        id: mkdirProcess
        command: ["mkdir", "-p", root.baseDir]
        running: false
        onExited: (code) => {
            if (code === 0 && !sessionLoaded) {
                sessionFile.path = sessionPath;
            }
        }
    }

    FileView {
        id: sessionFile
        path: "" // Set after mkdir
        blockWrites: true
        atomicWrites: true

        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data.version >= 3 && data.sessions && typeof data.sessions === "object") {
                    sessionsByConfig = data.sessions;
                } else if (data.version === 2 && data.sessions && typeof data.sessions === "object") {
                    sessionsByConfig = migrateModelScopedSessions(data.sessions);
                } else {
                    const legacyHash = data.providerConfigHash || computeConfigHash();
                    const separator = legacyHash.lastIndexOf("|");
                    const historyHash = (legacyHash.match(/\|/g) || []).length >= 2
                        ? legacyHash.substring(0, separator)
                        : legacyHash;
                    sessionsByConfig = {};
                    sessionsByConfig[historyHash] = Array.isArray(data.messages) ? data.messages : [];
                }
            } catch (e) {
                sessionsByConfig = {};
            }

            sessionLoaded = true;
            switchConfigHistory(computeConfigHash());
        }

        onLoadFailed: {
            sessionsByConfig = {};
            sessionLoaded = true;
            switchConfigHistory(computeConfigHash());
        }
    }

    function computeConfigHash() {
        return provider + "|" + baseUrl;
    }

    function latestMessageTimestamp(messages) {
        if (!Array.isArray(messages) || messages.length === 0)
            return 0;
        let latest = 0;
        for (let i = 0; i < messages.length; i++)
            latest = Math.max(latest, Number(messages[i]?.timestamp || 0));
        return latest;
    }

    function migrateModelScopedSessions(oldSessions) {
        const migrated = {};
        const selectedLegacyHash = provider + "|" + baseUrl + "|" + model;
        const selectedTargets = {};
        const keys = Object.keys(oldSessions || {});
        for (let i = 0; i < keys.length; i++) {
            const oldHash = keys[i];
            const separator = oldHash.lastIndexOf("|");
            const nextHash = separator >= 0 ? oldHash.substring(0, separator) : oldHash;
            const messages = Array.isArray(oldSessions[oldHash]) ? oldSessions[oldHash] : [];
            const shouldReplace = !Array.isArray(migrated[nextHash])
                || oldHash === selectedLegacyHash
                || (!selectedTargets[nextHash]
                    && latestMessageTimestamp(messages) > latestMessageTimestamp(migrated[nextHash]));
            if (shouldReplace) {
                migrated[nextHash] = messages;
                selectedTargets[nextHash] = oldHash === selectedLegacyHash;
            }
        }
        return migrated;
    }

    function persistCurrentMessagesForHash(configHash) {
        if (!configHash)
            return;
        const msgs = [];
        for (let i = 0; i < messagesModel.count; i++) {
            const m = messagesModel.get(i);
            if ((m.role === "user" || m.role === "assistant") && m.status !== "streaming") {
                msgs.push({
                    role: m.role,
                    content: m.content,
                    timestamp: m.timestamp,
                    id: m.id,
                    status: m.status
                });
            }
        }
        const capped = msgs.length > maxStoredMessages ? msgs.slice(msgs.length - maxStoredMessages) : msgs;
        const nextSessions = Object.assign({}, sessionsByConfig || {});
        nextSessions[configHash] = capped;
        sessionsByConfig = nextSessions;
    }

    function switchConfigHistory(nextHash) {
        if (!nextHash)
            return;

        const previousHash = providerConfigHash;
        if (previousHash && previousHash !== nextHash)
            persistCurrentMessagesForHash(previousHash)

        providerConfigHash = nextHash;
        const nextMessages = (sessionsByConfig && Array.isArray(sessionsByConfig[nextHash])) ? sessionsByConfig[nextHash] : [];
        loadMessages(nextMessages);
        saveSession();
    }

    function handleConfigChanged() {
        if (suppressConfigChange)
            return;
        const current = computeConfigHash();
        if (providerConfigHash && providerConfigHash !== current) {
            switchConfigHistory(current)
        } else {
            providerConfigHash = current;
            saveSession();
        }
    }

    function loadMessages(msgs) {
        messagesModel.clear();
        for (let i = 0; i < msgs.length; i++) {
            const m = msgs[i];
            if (!m || !m.role || !m.content)
                continue;
            messagesModel.append({
                role: m.role,
                content: m.content,
                timestamp: m.timestamp || Date.now(),
                id: m.id || (m.role + "-" + Date.now() + "-" + i),
                status: m.status || "ok"
            });
        }
        lastUserText = findLastUserText();
    }

    function saveSession() {
        const currentHash = providerConfigHash || computeConfigHash();
        persistCurrentMessagesForHash(currentHash)

        if (!sessionLoaded || !sessionFile.path)
            return;

        const data = {
            version: 3,
            providerConfigHash: currentHash,
            sessions: sessionsByConfig || {}
        };
        sessionFile.setText(JSON.stringify(data, null, 2));
    }

    function clearHistory(saveNow) {
        messagesModel.clear();
        isStreaming = false;
        activeStreamId = "";
        streamStartedAtMs = 0;
        isOnline = false;
        lastUserText = "";
        if (saveNow)
            saveSession();
    }

    function resolveApiKey() {
        const p = provider;

        function scopedEnv(id) {
            switch (id) {
            case "anthropic":
                return Quickshell.env("DMS_ANTHROPIC_API_KEY") || "";
            case "gemini":
                return Quickshell.env("DMS_GEMINI_API_KEY") || "";
            case "inception":
                return Quickshell.env("DMS_INCEPTION_API_KEY") || "";
            case "ollama":
                return "";
            case "custom":
                return Quickshell.env("DMS_CUSTOM_API_KEY") || "";
            default:
                return Quickshell.env("DMS_OPENAI_API_KEY") || "";
            }
        }

        function commonEnv(id) {
            switch (id) {
            case "anthropic":
                return Quickshell.env("ANTHROPIC_API_KEY") || "";
            case "gemini":
                return Quickshell.env("GEMINI_API_KEY") || "";
            case "inception":
                return Quickshell.env("INCEPTION_API_KEY") || "";
            case "ollama":
                return "";
            case "custom":
                return "";
            default:
                return Quickshell.env("OPENAI_API_KEY") || "";
            }
        }

        // Use local properties instead of SettingsData
        const sKey = sessionApiKey || "";
        const svKey = saveApiKey ? (apiKey || "") : "";
        const customEnvName = (apiKeyEnvVar || "").trim();
        const customEnv = customEnvName ? (Quickshell.env(customEnvName) || "") : "";
        const common = commonEnv(p);
        const scoped = scopedEnv(p);

        return sKey || svKey || customEnv || common || scoped || "";
    }

    function sendMessage(text) {
        if (!text || text.trim().length === 0)
            return;
        if (isStreaming && chatFetcher.running) {
            markError(activeStreamId, "Please wait until the current response finishes.");
            return;
        }
        startStreaming(text.trim(), true);
    }

    function retryLast() {
        if (isStreaming && chatFetcher.running)
            return;
        const text = lastUserText || findLastUserText();
        if (!text)
            return;
        startStreaming(text, false);
    }

    function regenerateFromMessageId(messageId) {
        if (!messageId || (isStreaming && chatFetcher.running))
            return;

        const assistantIdx = findIndexById(messageId);
        if (assistantIdx < 0) {
            retryLast();
            return;
        }

        const target = messagesModel.get(assistantIdx);
        if (!target || target.role !== "assistant") {
            retryLast();
            return;
        }

        let userText = "";
        for (let i = assistantIdx - 1; i >= 0; i--) {
            const m = messagesModel.get(i);
            if (m && m.role === "user" && m.status === "ok" && (m.content || "").trim().length > 0) {
                userText = m.content;
                break;
            }
        }
        if (!userText) {
            retryLast();
            return;
        }

        for (let i = messagesModel.count - 1; i >= assistantIdx; i--) {
            messagesModel.remove(i, 1);
        }
        lastUserText = userText;
        startStreaming(userText, false);
    }

    function startStreaming(text, addUser) {
        const now = Date.now();
        const streamId = "assistant-" + now;

        if (addUser) {
            messagesModel.append({ role: "user", content: text, timestamp: now, id: "user-" + now, status: "ok" });
            lastUserText = text;
        }

        messagesModel.append({ role: "assistant", content: "", timestamp: now + 1, id: streamId, status: "streaming" });
        activeStreamId = streamId;
        isStreaming = true;
        streamStartedAtMs = now;
        lastHttpStatus = 0;

        const payload = buildPayload(text);
        const curlCmd = buildCurlCommand(payload);
        if (!curlCmd) {
            markError(streamId, "No API key or provider configuration.");
            return;
        }

        streamCollector.lastLen = 0;
        streamBuffer = "";
        chatFetcher.command = curlCmd;
        chatFetcher.running = true;
        saveSession();
    }

    function cancel() {
        if (!isStreaming)
            return;
        chatFetcher.running = false;
        markError(activeStreamId, "Cancelled");
    }

    function findIndexById(msgId) {
        for (let i = 0; i < messagesModel.count; i++) {
            const itm = messagesModel.get(i);
            if (itm.id === msgId)
                return i;
        }
        return -1;
    }

    function markError(streamId, message) {
        const idx = findIndexById(streamId);
        if (idx >= 0) {
            messagesModel.setProperty(idx, "content", message);
            messagesModel.setProperty(idx, "status", "error");
        }
        isStreaming = false;
        activeStreamId = "";
        streamStartedAtMs = 0;
        saveSession();
    }

    function updateStreamContent(streamId, deltaText) {
        if (!deltaText)
            return;
        const idx = findIndexById(streamId);
        if (idx >= 0) {
            const cur = messagesModel.get(idx).content || "";
            messagesModel.setProperty(idx, "content", cur + deltaText);
            messagesModel.setProperty(idx, "status", "streaming");
        }
    }

    function getMessageContentById(msgId) {
        const idx = findIndexById(msgId);
        if (idx >= 0)
            return messagesModel.get(idx).content || "";
        return "";
    }

    function setMessageContentById(msgId, text) {
        const idx = findIndexById(msgId);
        if (idx >= 0) {
            messagesModel.setProperty(idx, "content", text || "");
        }
    }

    function finalizeStream(streamId) {
        const idx = findIndexById(streamId);
        if (idx >= 0) {
            messagesModel.setProperty(idx, "status", "ok");
        }
        isStreaming = false;
        activeStreamId = "";
        streamStartedAtMs = 0;
        isOnline = true;
        if (debugEnabled) {
            const text = getMessageContentById(streamId);
            const preview = (text || "").replace(/\s+/g, " ").slice(0, 300);
            console.log("[AIAssistantService] response finalized chars=", (text || "").length, "preview=", preview);
        }
        saveSession();
    }

    function buildPayload(latestText) {
        const msgs = [];
        let needUser = false;
        let turns = 0;
        const maxTurns = 20;

        for (let i = messagesModel.count - 1; i >= 0; i--) {
            const m = messagesModel.get(i);
            if (!m || m.status !== "ok")
                continue;
            if (m.role !== "user" && m.role !== "assistant")
                continue;

            if (!needUser) {
                if (m.role === "assistant" && m.content && m.content.trim().length > 0) {
                    msgs.unshift({ role: "assistant", content: m.content });
                    needUser = true;
                }
            } else {
                if (m.role === "user" && m.content && m.content.trim().length > 0) {
                    msgs.unshift({ role: "user", content: m.content });
                    needUser = false;
                    turns++;
                    if (turns >= maxTurns)
                        break;
                }
            }
        }

        msgs.push({ role: "user", content: latestText });
        const payload = {
            provider: provider,
            baseUrl: baseUrl,
            model: model,
            temperature: temperature,
            max_tokens: maxTokens,
            messages: msgs,
            stream: true,
            timeout: timeout
        };
        if (provider === "inception") {
            payload.inceptionReasoningEffort = inceptionReasoningEffort;
            payload.inceptionReasoningSummary = inceptionReasoningSummary;
            payload.inceptionReasoningSummaryWait = inceptionReasoningSummaryWait;
        } else if (provider === "gemini") {
            payload.geminiWebSearch = geminiWebSearch;
        }
        return payload;
    }

    function buildCurlCommand(payload) {
        const key = resolveApiKey();
        // Local/self-hosted providers can be keyless.
        if (!key && provider !== "custom" && provider !== "ollama")
            return null;

        const req = AIApiAdapters.buildRequest(provider, payload, key);
        if (debugEnabled && req) {
            const redactedUrl = key ? (req.url || "").replace(key, "[REDACTED]") : (req.url || "");
            const bodyPreview = (req.body || "");
            console.log("[AIAssistantService] request provider=", provider, "url=", redactedUrl);
            console.log("[AIAssistantService] request body(preview)=", bodyPreview.slice(0, 800));
        }

        return AIApiAdapters.buildCurlCommand(provider, payload, key);
    }

    property string streamBuffer: ""

    function handleStreamChunk(chunk) {
        let buffer = streamBuffer + chunk;
        const parts = buffer.split(/\r?\n/);

        if (buffer.length > 0 && !buffer.endsWith("\n") && !buffer.endsWith("\r")) {
            streamBuffer = parts.pop();
        } else {
            streamBuffer = "";
        }

        for (let i = 0; i < parts.length; i++) {
            const line = parts[i].trim();
            if (!line)
                continue;

            if (provider === "ollama") {
                parseProviderDelta(line);
                continue;
            }

            if (line === "data: [DONE]" || line === "data:[DONE]") {
                finalizeStream(activeStreamId);
                continue;
            }

            if (line.startsWith("data:")) {
                const jsonPart = line.substring(5).trim();
                parseProviderDelta(jsonPart);
            }
        }
    }

    function parseProviderDelta(jsonText) {
        try {
            const data = JSON.parse(jsonText);
            if (debugEnabled && provider === "gemini") {
                console.log("[AIAssistantService] gemini chunk:", JSON.stringify(data).slice(0, 200));
            }
            if (provider === "anthropic") {
                const delta = data.delta?.text || "";
                if (delta)
                    updateStreamContent(activeStreamId, delta);
                if (data.stop_reason)
                    finalizeStream(activeStreamId);
            } else if (provider === "ollama") {
                const delta = data.message?.content || "";
                if (delta)
                    updateStreamContent(activeStreamId, delta);
                if (data.done)
                    finalizeStream(activeStreamId);
            } else if (provider === "gemini") {
                const chunks = Array.isArray(data) ? data : [data];
                chunks.forEach(chunk => {
                    const candidate = chunk.candidates?.[0];
                    const parts = candidate?.content?.parts || [];
                    let hasContent = false;
                    let hasNonEmptyText = false;
                    parts.forEach(p => {
                        if (p.text !== undefined)
                            hasContent = true;
                        if (p.text) {
                            hasNonEmptyText = true;
                            updateStreamContent(activeStreamId, p.text);
                        }
                    });
                    // Finalize on finishReason OR if we get empty text with metadata (like thoughtSignature)
                    const finishReason = candidate?.finishReason;
                    if (finishReason && finishReason !== "FINISH_REASON_UNSPECIFIED") {
                        finalizeStream(activeStreamId);
                    }
                    // Some Gemini variants emit usageMetadata before visible text arrives.
                    // Only use usageMetadata as an end-of-stream fallback once we've already
                    // received visible output and this chunk contains no content parts.
                    const existing = getMessageContentById(activeStreamId);
                    if (chunk.usageMetadata && !hasContent && existing && existing.length > 0) {
                        finalizeStream(activeStreamId);
                    } else if (chunk.usageMetadata && hasContent && !hasNonEmptyText && existing && existing.length > 0) {
                        finalizeStream(activeStreamId);
                    }
                });
            } else { // openai
                const deltas = data.choices?.[0]?.delta?.content;
                if (Array.isArray(deltas)) {
                    deltas.forEach(d => {
                        if (d.text)
                            updateStreamContent(activeStreamId, d.text);
                    });
                } else if (typeof deltas === "string") {
                    updateStreamContent(activeStreamId, deltas);
                }

                if (data.choices?.[0]?.finish_reason) {
                    finalizeStream(activeStreamId);
                }
            }
        } catch (e) {
            // ignore malformed chunks
        }
    }

    function handleStreamFinished(text) {
        const match = text.match(/DMS_STATUS:(\d+)/);
        if (match) {
            lastHttpStatus = parseInt(match[1]);
        }

        function stripStatusFooter(fullText) {
            const marker = "\nDMS_STATUS:";
            const idx = fullText.lastIndexOf(marker);
            if (idx >= 0)
                return fullText.substring(0, idx);
            return fullText;
        }

        const bodyText = stripStatusFooter(text || "").trim();
        const bodyPreview = bodyText.length > 0 ? bodyText.slice(0, 600) : "";

        if (isStreaming) {
            const existing = getMessageContentById(activeStreamId);
            if ((!existing || existing.length === 0) && bodyText && lastHttpStatus > 0 && lastHttpStatus < 400) {
                const parsed = extractNonStreamingAssistantText(bodyText);
                if (parsed && parsed.length > 0) {
                    setMessageContentById(activeStreamId, parsed);
                }
            }
        }

        if (lastHttpStatus >= 400 && isStreaming) {
            const msg = bodyPreview
                ? ("Request failed (HTTP " + lastHttpStatus + "): " + bodyPreview)
                : ("Request failed (HTTP " + lastHttpStatus + ")");
            markError(activeStreamId, msg);
            return;
        }

        if (isStreaming) {
            finalizeStream(activeStreamId);
        }
    }

    function extractNonStreamingAssistantText(bodyText) {
        if (provider === "ollama") {
            const lines = bodyText.split(/\r?\n/);
            let out = "";
            for (let i = 0; i < lines.length; i++) {
                const line = lines[i].trim();
                if (!line)
                    continue;
                try {
                    const chunk = JSON.parse(line);
                    if (chunk.message?.content)
                        out += chunk.message.content;
                } catch (innerErr) {
                    // ignore malformed lines
                }
            }
            return out;
        }

        try {
            const data = JSON.parse(bodyText);
            if (provider === "anthropic") {
                const content = data.content;
                if (Array.isArray(content)) {
                    let out = "";
                    for (let i = 0; i < content.length; i++) {
                        const c = content[i];
                        if (c && c.text)
                            out += c.text;
                    }
                    return out;
                }
                return data.text || "";
            }

            if (provider === "gemini") {
                const chunks = Array.isArray(data) ? data : [data];
                let out = "";
                chunks.forEach(chunk => {
                    const parts = chunk.candidates?.[0]?.content?.parts || [];
                    parts.forEach(p => {
                        if (p && p.text)
                            out += p.text;
                    });
                });
                return out;
            }

            const msg = data.choices?.[0]?.message?.content;
            if (typeof msg === "string")
                return msg;
            const text = data.choices?.[0]?.text;
            if (typeof text === "string")
                return text;
        } catch (e) {
            // ignore
        }
        return "";
    }

    function findLastUserText() {
        for (let i = messagesModel.count - 1; i >= 0; i--) {
            const m = messagesModel.get(i);
            if (m.role === "user" && m.status === "ok")
                return m.content;
        }
        return "";
    }

    function refreshAvailableModels(force) {
        const key = resolveApiKey();
        const needsKey = provider !== "ollama" && provider !== "custom";
        if (needsKey && !key) {
            if (modelFetcher.running) {
                pendingModelRefresh = false;
                modelFetcher.running = false;
            }
            availableModels = [];
            availableModelDetails = [];
            modelsLoading = false;
            modelsError = "";
            modelFetchOutput = "";
            modelDiscoveryConfig = "";
            return;
        }

        const normalizedBase = AIApiAdapters.normalizeBaseUrl(baseUrl || defaultsForProvider(provider).baseUrl);
        const nextConfig = provider + "|" + normalizedBase + "|" + key;
        if (!force && modelDiscoveryConfig === nextConfig)
            return;

        if (modelsLoading) {
            const activeConfig = modelFetchProvider + "|" + modelFetchBaseUrl + "|" + modelFetchCredential;
            if (activeConfig === nextConfig)
                return;
            pendingModelRefresh = true;
            modelFetcher.running = false;
            return;
        }

        const command = AIApiAdapters.buildModelsCurlCommand(provider, normalizedBase, key);
        if (!command)
            return;

        modelsLoading = true;
        modelsError = "";
        availableModels = [];
        availableModelDetails = [];
        modelFetchOutput = "";
        modelFetchCollector.lastLength = 0;
        modelFetchProvider = provider;
        modelFetchBaseUrl = normalizedBase;
        modelFetchCredential = key;
        modelFetcher.command = command;
        modelFetcher.running = true;
    }

    function modelDiscoveryStatusText() {
        if (modelsLoading)
            return "Loading available models…";
        if (modelsError)
            return modelsError;
        if ((availableModels?.length ?? 0) > 0)
            return "%1 available model(s) detected.".arg(availableModels.length);
        if (provider !== "ollama" && provider !== "custom" && !resolveApiKey())
            return "Enter an API key to load available models.";
        return "No model list loaded. Manual model IDs remain available.";
    }

    function setCurrentModel(nextModel) {
        const trimmed = String(nextModel || "").trim();
        if (!trimmed || trimmed === model)
            return;

        model = trimmed;
        const nextProviders = Object.assign({}, providers || {});
        const active = Object.assign({}, nextProviders[provider] || normalizedProfile(provider, null));
        active.model = trimmed;
        nextProviders[provider] = normalizedProfile(provider, active);
        providers = nextProviders;
        PluginService.savePluginData(pluginId, "providers", nextProviders);
        syncLegacySnapshot(nextProviders[provider]);
    }

    Process {
        id: modelFetcher
        running: false

        stdout: StdioCollector {
            id: modelFetchCollector
            property int lastLength: 0

            onTextChanged: {
                const current = text || "";
                if (current.length < lastLength)
                    lastLength = 0;
                root.modelFetchOutput += current.substring(lastLength);
                lastLength = current.length;
            }
        }

        onExited: exitCode => {
            modelsLoading = false;

            const currentBase = AIApiAdapters.normalizeBaseUrl(baseUrl || defaultsForProvider(provider).baseUrl);
            const stale = provider !== modelFetchProvider
                || currentBase !== modelFetchBaseUrl
                || resolveApiKey() !== modelFetchCredential;
            if (pendingModelRefresh || stale) {
                pendingModelRefresh = false;
                Qt.callLater(() => root.refreshAvailableModels(true));
                return;
            }

            if (exitCode !== 0) {
                availableModels = [];
                availableModelDetails = [];
                modelsError = "Unable to load available models.";
                return;
            }

            try {
                const statusMatch = modelFetchOutput.match(/\nDMS_STATUS:(\d{3})\s*$/);
                const status = statusMatch ? Number(statusMatch[1]) : 0;
                const responseBody = statusMatch
                    ? modelFetchOutput.substring(0, statusMatch.index)
                    : modelFetchOutput;
                if (status < 200 || status >= 300) {
                    availableModels = [];
                    availableModelDetails = [];
                    modelsError = status === 401 || status === 403
                        ? "Unable to load models: check the API key."
                        : "Unable to load models (HTTP %1).".arg(status || "unknown");
                    modelDiscoveryConfig = modelFetchProvider + "|" + modelFetchBaseUrl + "|" + modelFetchCredential;
                    return;
                }

                const details = AIApiAdapters.parseModelsResponse(modelFetchProvider, responseBody);
                availableModelDetails = details;
                availableModels = details.map(item => item.id);
                modelsError = details.length > 0 ? "" : "No models found.";
                modelDiscoveryConfig = modelFetchProvider + "|" + modelFetchBaseUrl + "|" + modelFetchCredential;
            } catch (e) {
                availableModels = [];
                availableModelDetails = [];
                modelsError = "Unable to parse the model list.";
            }
        }
    }

    Process {
        id: chatFetcher
        running: false

        stdout: StdioCollector {
            id: streamCollector
            property int lastLen: 0

            onTextChanged: {
                const newData = text.substring(lastLen);
                lastLen = text.length;
                handleStreamChunk(newData);
            }

            onStreamFinished: {
                handleStreamFinished(text);
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 && isStreaming) {
                markError(activeStreamId, "Request failed (exit " + exitCode + ")");
            }
        }
    }
}
