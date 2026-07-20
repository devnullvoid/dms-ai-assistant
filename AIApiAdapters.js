// QML JS library (not an ES module).
// Provider adapters for building curl commands.
// v1 supports OpenAI-compatible, Anthropic, Gemini, and Ollama streaming.
// "custom" currently follows OpenAI-compatible semantics.

.pragma library

function normalizeBaseUrl(url) {
    const u = (url || "").trim();
    if (!u)
        return "";
    return u.endsWith("/") ? u.slice(0, -1) : u;
}

function openaiChatCompletionsUrl(baseUrl) {
    // Support the common OpenAI-style host base (https://api.openai.com -> /v1/chat/completions)
    // and versioned bases used by local servers or other providers (..../v1 or ..../v4 -> /chat/completions).
    const b = normalizeBaseUrl(baseUrl || "https://api.openai.com");
    if (/\/v\d+$/.test(b))
        return b + "/chat/completions";
    return b + "/v1/chat/completions";
}

function openaiModelsUrl(baseUrl) {
    const b = normalizeBaseUrl(baseUrl || "https://api.openai.com");
    if (/\/v\d+$/.test(b))
        return b + "/models";
    return b + "/v1/models";
}

function buildCurlCommand(provider, payload, apiKey) {
    const request = buildRequest(provider, payload, apiKey);
    if (!request || !request.url)
        return null;

    const timeout = payload.timeout || 30;
    const baseCmd = [
        "curl",
        "-N",
        "-sS",
        "--no-buffer",
        "--show-error",
        "--connect-timeout",
        "5",
        "--max-time",
        String(timeout),
        "-w",
        "\\nDMS_STATUS:%{http_code}\\n"
    ];

    const cmd = baseCmd
        .concat(request.headers || [])
        .concat(["-d", request.body || "{}", request.url]);
    return cmd;
}

function buildModelsRequest(provider, baseUrl, apiKey) {
    const base = normalizeBaseUrl(baseUrl);
    switch (provider) {
    case "anthropic":
        return {
            url: (base || "https://api.anthropic.com") + "/v1/models?limit=1000",
            headers: [
                "-H", "x-api-key: " + apiKey,
                "-H", "anthropic-version: 2023-06-01"
            ]
        };
    case "gemini":
        return {
            url: (base || "https://generativelanguage.googleapis.com")
                + "/v1beta/models?pageSize=1000&key=" + encodeURIComponent(apiKey),
            headers: []
        };
    case "inception":
        return {
            url: (base || "https://api.inceptionlabs.ai/v1") + "/chat/completions/models",
            headers: ["-H", "Authorization: Bearer " + apiKey]
        };
    case "ollama":
        return {
            url: (base || "http://localhost:11434") + "/api/tags",
            headers: []
        };
    case "custom":
        return {
            url: openaiModelsUrl(base || "https://api.openai.com"),
            headers: apiKey ? ["-H", "Authorization: Bearer " + apiKey] : []
        };
    default:
        return {
            url: openaiModelsUrl(base || "https://api.openai.com"),
            headers: ["-H", "Authorization: Bearer " + apiKey]
        };
    }
}

function buildModelsCurlCommand(provider, baseUrl, apiKey) {
    const request = buildModelsRequest(provider, baseUrl, apiKey);
    if (!request || !request.url)
        return null;
    return [
        "curl",
        "-sS",
        "--show-error",
        "--connect-timeout", "5",
        "--max-time", "15",
        "-w", "\\nDMS_STATUS:%{http_code}\\n"
    ].concat(request.headers || []).concat([request.url]);
}

function parseModelsResponse(provider, responseText) {
    const parsed = JSON.parse(responseText || "{}");
    let rawModels = [];
    if (provider === "ollama")
        rawModels = Array.isArray(parsed.models) ? parsed.models : [];
    else if (provider === "gemini")
        rawModels = Array.isArray(parsed.models) ? parsed.models : [];
    else
        rawModels = Array.isArray(parsed.data) ? parsed.data : [];

    const models = [];
    const seen = {};
    for (let i = 0; i < rawModels.length; i++) {
        const raw = rawModels[i] || {};
        if (provider === "gemini") {
            const methods = Array.isArray(raw.supportedGenerationMethods) ? raw.supportedGenerationMethods : [];
            if (methods.indexOf("generateContent") === -1)
                continue;
        }

        let id = "";
        if (provider === "ollama")
            id = String(raw.name || raw.model || "").trim();
        else if (provider === "gemini")
            id = String(raw.baseModelId || raw.name || "").replace(/^models\//, "").trim();
        else
            id = String(raw.id || "").trim();
        if (!id || seen[id])
            continue;

        seen[id] = true;
        models.push({
            id: id,
            displayName: String(raw.display_name || raw.displayName || raw.name || id).replace(/^models\//, ""),
            contextLength: Number(raw.context_length || raw.inputTokenLimit || 0),
            outputTokenLimit: Number(raw.max_output_length || raw.max_completion_tokens || raw.outputTokenLimit || 0),
            supportedParameters: Array.isArray(raw.supported_sampling_parameters)
                ? raw.supported_sampling_parameters.slice()
                : (Array.isArray(raw.supported_parameters) ? raw.supported_parameters.slice() : []),
            supportsGenerateContent: provider === "gemini"
        });
    }

    models.sort((a, b) => a.id.localeCompare(b.id));
    return models;
}

function buildRequest(provider, payload, apiKey) {
    switch (provider) {
    case "anthropic":
        return anthropicRequest(payload, apiKey);
    case "gemini":
        return geminiRequest(payload, apiKey);
    case "inception":
        return inceptionRequest(payload, apiKey);
    case "ollama":
        return ollamaRequest(payload);
    case "custom":
        return customRequest(payload, apiKey);
    default:
        return openaiRequest(payload, apiKey);
    }
}

function openaiRequest(payload, apiKey) {
    return openaiCompatibleRequest(payload, apiKey, "max_completion_tokens");
}

function openaiCompatibleRequest(payload, apiKey, tokenParameter) {
    const url = openaiChatCompletionsUrl(payload.baseUrl || "https://api.openai.com");
    const headers = ["-H", "Content-Type: application/json", "-H", "Authorization: Bearer " + apiKey];
    const body = {
        model: payload.model,
        messages: payload.messages,
        temperature: payload.temperature || 0.7,
        stream: true
    };
    body[tokenParameter] = payload.max_tokens || 1024;
    return { url, headers, body: JSON.stringify(body) };
}

function inceptionRequest(payload, apiKey) {
    // Mercury 2 params: https://docs.inceptionlabs.ai/get-started/api-parameters
    const url = openaiChatCompletionsUrl(payload.baseUrl || "https://api.inceptionlabs.ai/v1");
    const headers = ["-H", "Content-Type: application/json", "-H", "Authorization: Bearer " + apiKey];
    const maxTok = payload.max_tokens;
    const mt = (typeof maxTok === "number" && maxTok > 0) ? Math.min(50000, maxTok) : 8192;
    let t = (typeof payload.temperature === "number") ? payload.temperature : 0.75;
    if (t < 0.5)
        t = 0.5;
    if (t > 1.0)
        t = 1.0;
    const body = {
        model: payload.model,
        messages: payload.messages,
        max_tokens: mt,
        temperature: t,
        stream: true
    };
    const efforts = ["instant", "low", "medium", "high"];
    const effort = String(payload.inceptionReasoningEffort || "medium").toLowerCase();
    if (efforts.indexOf(effort) >= 0)
        body.reasoning_effort = effort;
    body.reasoning_summary = payload.inceptionReasoningSummary !== false;
    if (payload.inceptionReasoningSummaryWait === true)
        body.reasoning_summary_wait = true;
    return { url, headers, body: JSON.stringify(body) };
}

function anthropicRequest(payload, apiKey) {
    const url = (payload.baseUrl || "https://api.anthropic.com") + "/v1/messages";
    const headers = [
        "-H", "Content-Type: application/json",
        "-H", "x-api-key: " + apiKey,
        "-H", "anthropic-version: 2023-06-01"
    ];
    const body = {
        model: payload.model,
        messages: payload.messages.map(m => ({ role: m.role === "assistant" ? "assistant" : "user", content: m.content })),
        max_tokens: payload.max_tokens || 1024,
        temperature: payload.temperature || 0.7,
        stream: true
    };
    return { url, headers, body: JSON.stringify(body) };
}

function geminiRequest(payload, apiKey) {
    const url = (payload.baseUrl || "https://generativelanguage.googleapis.com")
        + "/v1beta/models/" + (payload.model || "gemini-2.5-flash") + ":streamGenerateContent"
        + "?key=" + apiKey + "&alt=sse";
    const headers = ["-H", "Content-Type: application/json"];
    const contents = payload.messages.map(m => ({
        role: m.role === "user" ? "user" : "model",
        parts: [{ text: m.content }]
    }));
    const body = {
        contents,
        generationConfig: {
            temperature: payload.temperature || 0.7,
            maxOutputTokens: payload.max_tokens || 1024
        }
    };
    if (payload.geminiWebSearch === true)
        body.tools = [{ google_search: {} }];
    return { url, headers, body: JSON.stringify(body) };
}

function customRequest(payload, apiKey) {
    // v1 fallback: treat as OpenAI-compatible.
    return openaiCompatibleRequest(payload, apiKey, "max_tokens");
}

function ollamaRequest(payload) {
    const url = normalizeBaseUrl(payload.baseUrl || "http://localhost:11434") + "/api/chat";
    const body = {
        model: payload.model,
        messages: payload.messages,
        stream: true,
        options: {
            temperature: payload.temperature || 0.7,
            num_predict: payload.max_tokens || 1024
        }
    };
    return {
        url,
        headers: ["-H", "Content-Type: application/json"],
        body: JSON.stringify(body)
    };
}
