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
    property int maxStoredMessages: 50

    property ListModel messagesModel: ListModel {}
    property int messageCount: messagesModel.count
    property bool isStreaming: false
    property bool isOnline: false
    property string activeStreamId: ""
    property string lastUserText: ""
    property int lastHttpStatus: 0

    // Settings
    property string provider: "openai"
    property string baseUrl: "https://api.openai.com"
    property string model: "gpt-4.1-mini"
    property real temperature: 0.7
    property int maxTokens: 4096
    property int timeout: 30
    property string apiKey: ""
    property bool saveApiKey: false
    property string sessionApiKey: "" // In-memory key
    property string apiKeyEnvVar: ""
    property bool useMonospace: false

    readonly property bool debugEnabled: (Quickshell.env("DMS_LOG_LEVEL") || "").toLowerCase() === "debug"

    onProviderChanged: handleConfigChanged()
    onBaseUrlChanged: handleConfigChanged()
    onModelChanged: handleConfigChanged()

    function loadSettings() {
        provider = String(PluginService.loadPluginData(pluginId, "provider", "openai")).trim()
        baseUrl = String(PluginService.loadPluginData(pluginId, "baseUrl", "https://api.openai.com")).trim()
        model = String(PluginService.loadPluginData(pluginId, "model", "gpt-4.1-mini")).trim()
        temperature = PluginService.loadPluginData(pluginId, "temperature", 0.7)
        maxTokens = PluginService.loadPluginData(pluginId, "maxTokens", 4096)
        timeout = PluginService.loadPluginData(pluginId, "timeout", 30)
        apiKey = String(PluginService.loadPluginData(pluginId, "apiKey", "")).trim()
        saveApiKey = PluginService.loadPluginData(pluginId, "saveApiKey", false)
        apiKeyEnvVar = String(PluginService.loadPluginData(pluginId, "apiKeyEnvVar", "")).trim()
        useMonospace = PluginService.loadPluginData(pluginId, "useMonospace", false)
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
                const storedHash = data.providerConfigHash || "";
                const currentHash = computeConfigHash();

                if (storedHash && storedHash !== currentHash) {
                    providerConfigHash = currentHash;
                    clearHistory(false);
                } else {
                    providerConfigHash = storedHash || currentHash;
                    loadMessages(data.messages || []);
                }
            } catch (e) {
                providerConfigHash = computeConfigHash();
                clearHistory(false);
            }
            sessionLoaded = true;
        }

        onLoadFailed: {
            providerConfigHash = computeConfigHash();
            sessionLoaded = true;
        }
    }

    function computeConfigHash() {
        return provider + "|" + baseUrl + "|" + model;
    }

    function handleConfigChanged() {
        const current = computeConfigHash();
        if (providerConfigHash && providerConfigHash !== current) {
            providerConfigHash = current;
            clearHistory(true);
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
        const data = {
            version: 1,
            providerConfigHash: providerConfigHash || computeConfigHash(),
            messages: capped
        };
        sessionFile.setText(JSON.stringify(data, null, 2));
    }

    function clearHistory(saveNow) {
        messagesModel.clear();
        isStreaming = false;
        activeStreamId = "";
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
        return {
            provider: provider,
            baseUrl: baseUrl,
            model: model,
            temperature: temperature,
            max_tokens: maxTokens,
            messages: msgs,
            stream: true,
            timeout: timeout
        };
    }

    function buildCurlCommand(payload) {
        const key = resolveApiKey();
        if (!key)
            return null;

        const req = AIApiAdapters.buildRequest(provider, payload, key);
        if (debugEnabled && req) {
            const redactedUrl = (req.url || "").replace(key, "[REDACTED]");
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
            if (provider === "anthropic") {
                const delta = data.delta?.text || "";
                if (delta)
                    updateStreamContent(activeStreamId, delta);
                if (data.stop_reason)
                    finalizeStream(activeStreamId);
            } else if (provider === "gemini") {
                const parts = data.candidates?.[0]?.content?.parts || [];
                parts.forEach(p => {
                    if (p.text)
                        updateStreamContent(activeStreamId, p.text);
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
                const parts = data.candidates?.[0]?.content?.parts || [];
                let out = "";
                parts.forEach(p => {
                    if (p && p.text)
                        out += p.text;
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
