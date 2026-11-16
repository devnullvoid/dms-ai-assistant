.pragma library

function titleFromMessages(messages, fallback) {
    for (let i = 0; i < messages.length; i++) {
        if (messages[i] && messages[i].role === "user" && String(messages[i].content || "").trim())
            return String(messages[i].content).replace(/\s+/g, " ").trim().slice(0, 48);
    }
    return fallback || "New chat";
}

function storedMessages(messages, limit) {
    return (Array.isArray(messages) ? messages : []).filter(message => message
        && (message.role === "user" || message.role === "assistant") && message.status !== "streaming")
        .slice(-limit).map(message => ({role: message.role, content: String(message.content || ""),
            timestamp: message.timestamp || 0, id: String(message.id || ""), status: message.status || "ok"}));
}

function restore(data, fallbackConfig, limit) {
    if (!data || typeof data !== "object" || Array.isArray(data))
        throw new Error("Invalid conversation file");
    const groups = {};
    if (data.version === 4) {
        if (!data.conversationGroups || typeof data.conversationGroups !== "object" || Array.isArray(data.conversationGroups))
            throw new Error("Invalid conversation groups");
        for (const key of Object.keys(data.conversationGroups)) {
            const group = data.conversationGroups[key];
            if (!group || !Array.isArray(group.tabs) || group.tabs.length === 0)
                throw new Error("Invalid conversation group");
            const ids = {};
            const tabs = group.tabs.map(tab => {
                if (!tab || !tab.id || ids[tab.id] || !Array.isArray(tab.messages))
                    throw new Error("Invalid conversation");
                ids[tab.id] = true;
                return {id: String(tab.id), title: String(tab.title || "New chat").slice(0, 80),
                    customTitle: !!tab.customTitle, messages: storedMessages(tab.messages, limit),
                    draft: String(tab.draft || ""), presetId: String(tab.presetId || ""),
                    modelOverrides: tab.modelOverrides && typeof tab.modelOverrides === "object" ? Object.assign({}, tab.modelOverrides) : null};
            });
            groups[key] = {activeId: ids[group.activeId] ? group.activeId : tabs[0].id, tabs: tabs};
        }
        return groups;
    }

    let legacy;
    if (data.version === 2 || data.version === 3) {
        if (!data.sessions || typeof data.sessions !== "object" || Array.isArray(data.sessions))
            throw new Error("Invalid legacy sessions");
        legacy = data.sessions;
    } else if (Array.isArray(data.messages)) {
        legacy = {};
        legacy[data.providerConfigHash || fallbackConfig] = data.messages;
    } else {
        throw new Error("Unsupported conversation file");
    }

    let sequence = 0;
    for (const key of Object.keys(legacy)) {
        if (!Array.isArray(legacy[key]))
            throw new Error("Invalid legacy history");
        const modelScoped = data.version === 2 || (data.version !== 3 && (key.match(/\|/g) || []).length >= 2);
        const separator = key.lastIndexOf("|");
        const config = modelScoped ? key.substring(0, separator) : key;
        const messages = storedMessages(legacy[key], limit);
        const tab = {id: "legacy-" + sequence++, title: modelScoped ? key.substring(separator + 1)
            : titleFromMessages(messages, "New chat"), customTitle: modelScoped, messages: messages, draft: ""};
        if (!groups[config])
            groups[config] = {activeId: tab.id, tabs: []};
        groups[config].tabs.push(tab);
        if (key === data.providerConfigHash)
            groups[config].activeId = tab.id;
    }
    return groups;
}
