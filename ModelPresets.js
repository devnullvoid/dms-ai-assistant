.pragma library

function fields(provider) {
    const result = ["model", "temperature", "maxTokens", "timeout"];
    if (provider === "gemini")
        result.push("geminiWebSearch");
    if (provider === "inception")
        result.push("inceptionReasoningEffort", "inceptionReasoningSummary", "inceptionReasoningSummaryWait");
    return result;
}

function values(provider, source) {
    const result = {};
    for (const field of fields(provider)) {
        if (source && source[field] !== undefined)
            result[field] = source[field];
    }
    return result;
}

function same(provider, left, right) {
    return JSON.stringify(values(provider, left)) === JSON.stringify(values(provider, right));
}

function restore(raw, providers) {
    const result = {};
    for (const provider of Object.keys(providers)) {
        const group = raw && raw[provider];
        const ids = Object.create(null);
        const names = Object.create(null);
        const presets = [];
        for (const preset of (group && Array.isArray(group.presets) ? group.presets : [])) {
            if (!preset || typeof preset !== "object")
                continue;
            const id = String(preset.id || "");
            const name = String(preset.name || "").trim().slice(0, 60);
            if (!id || !name || ids[id] || names[name.toLowerCase()])
                continue;
            ids[id] = true;
            names[name.toLowerCase()] = true;
            presets.push({id: id, name: name, values: values(provider,
                Object.assign({}, providers[provider], preset.values || {}))});
        }
        if (!presets.length)
            presets.push({id: "default", name: "Default", values: values(provider, providers[provider])});
        result[provider] = {selectedId: presets.some(preset => preset.id === group?.selectedId)
            ? group.selectedId : presets[0].id, presets: presets};
    }
    return result;
}
