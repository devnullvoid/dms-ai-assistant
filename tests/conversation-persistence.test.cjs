const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('real service migrates a session file and restores tabs in a second process', () => {
    const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'dms-ai-tab-persistence-'));
    try {
        const repo = path.join(__dirname, '..');
        let service = fs.readFileSync(path.join(repo, 'AIAssistantService.qml'), 'utf8');
        service = service.replace(/^    readonly property string baseDir:.*$/m, '    readonly property string baseDir: Quickshell.env("DMS_AI_TEST_STATE")');
        const refresh = service.match(/^    function refreshAvailableModels\(force\) \{[\s\S]*?^    \}/m)[0];
        service = service.replace(refresh, '    function refreshAvailableModels(force) {}');
        fs.writeFileSync(path.join(fixture, 'AIAssistantService.qml'), service);
        for (const file of ['ConversationStore.js', 'AIApiAdapters.js', 'ModelPresets.js'])
            fs.copyFileSync(path.join(repo, file), path.join(fixture, file));
        fs.mkdirSync(path.join(fixture, 'Common'));
        fs.writeFileSync(path.join(fixture, 'Common/qmldir'), 'module qs.Common\nsingleton Paths 1.0 Paths.qml\n');
        fs.writeFileSync(path.join(fixture, 'Common/Paths.qml'), 'pragma Singleton\nimport QtQuick\nQtObject { function strip(value) { return String(value); } }\n');
        fs.mkdirSync(path.join(fixture, 'Services'));
        fs.writeFileSync(path.join(fixture, 'Services/qmldir'), 'module qs.Services\nsingleton PluginService 1.0 PluginService.qml\n');
        fs.writeFileSync(path.join(fixture, 'Services/PluginService.qml'), `pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
QtObject {
    signal pluginDataChanged(string pluginId)
    property var data: null
    property FileView config: FileView { path: Quickshell.env("DMS_AI_TEST_CONFIG"); blockLoading: true; blockWrites: true }
    function ensureLoaded() {
        if (data === null) data = JSON.parse(config.text());
    }
    function loadPluginData(id, key, fallback) {
        ensureLoaded();
        return data[key] === undefined ? fallback : data[key];
    }
    function savePluginData(id, key, value) {
        ensureLoaded();
        const next = Object.assign({}, data);
        next[key] = value;
        data = next;
        config.setText(JSON.stringify(data));
        pluginDataChanged(id);
    }
}`);
        fs.writeFileSync(path.join(fixture, 'shell.qml'), `import QtQuick
import Quickshell
import Quickshell.Io
ShellRoot {
    id: root
    property bool checked: false
    AIAssistantService { id: service }
    property FileView marker: FileView { path: Quickshell.env("DMS_AI_TEST_RESULT"); blockWrites: true }
    Connections {
        target: service
        function onSessionLoadedChanged() { if (service.sessionLoaded) Qt.callLater(root.check); }
        function onHistoryErrorChanged() {
            if (Quickshell.env("DMS_AI_TEST_PHASE") === "corrupt") Qt.callLater(root.checkCorrupt);
        }
    }
    Timer { interval: 10000; running: true; onTriggered: { console.error("FAIL: loading timed out"); Qt.exit(1); } }
    function check() {
        if (checked) return;
        checked = true;
        try {
            if (Quickshell.env("DMS_AI_TEST_PHASE") === "write") {
                if (service.messageCount !== 1 || service.messagesModel.get(0).content !== "legacy prompt") throw new Error("Legacy history lost");
                if (!service.createConversation()) throw new Error("Create failed");
                service.renameConversation(service.activeConversationId, "Research");
                service.setCurrentModel("preset-fixture");
                if (!service.createModelPreset("Research model")) throw new Error("Preset create failed");
                service.messagesModel.append({role: "user", content: "second prompt", id: "second", timestamp: 2, status: "ok"});
                service.conversationDraft = "unsent draft";
                service.saveSession();
            } else if (Quickshell.env("DMS_AI_TEST_PHASE") === "read") {
                if (service.conversations.length !== 2 || service.conversationDraft !== "unsent draft") throw new Error("Tabs/draft not restored");
                if (service.conversations.find(tab => tab.id === service.activeConversationId).title !== "Research") throw new Error("Title/selection not restored");
                if (service.messagesModel.get(0).content !== "second prompt") throw new Error("Wrong active history");
                if (service.model !== "preset-fixture" || service.activePresetName !== "Research model" || service.customModelSettings) throw new Error("Preset not restored");
                service.selectConversation(service.conversations[0].id);
                if (service.messagesModel.get(0).content !== "legacy prompt") throw new Error("Migrated history not retained");
                if (service.model !== "fixture" || service.activePresetName !== "Default") throw new Error("Tab default preset not restored");
            } else {
                if (service.messageCount !== 0 || service.conversations.length !== 1 || service.historyError) throw new Error("Missing session file was not initialized");
            }
            marker.setText("passed");
            Qt.exit(0);
        } catch (error) { console.error("FAIL: " + error.message); Qt.exit(1); }
    }
    function checkCorrupt() {
        if (service.sessionLoaded || !service.historyError) { console.error("FAIL: corrupt history accepted"); Qt.exit(1); return; }
        marker.setText("passed");
        Qt.exit(0);
    }
}`);
        const state = path.join(fixture, 'state');
        fs.mkdirSync(state);
        const config = path.join(fixture, 'config.json');
        fs.writeFileSync(config, JSON.stringify({provider: 'gemini', providers: {gemini: {baseUrl: 'https://fixture.invalid', model: 'fixture'}}}));
        fs.writeFileSync(path.join(state, 'session.json'), JSON.stringify({version: 3, sessions: {
            'gemini|https://fixture.invalid': [{role: 'user', content: 'legacy prompt', id: 'legacy', timestamp: 1, status: 'ok'}],
        }}));
        for (const phase of ['write', 'read', 'missing', 'corrupt']) {
            if (phase === 'missing') fs.unlinkSync(path.join(state, 'session.json'));
            if (phase === 'corrupt') fs.writeFileSync(path.join(state, 'session.json'), 'invalid JSON must be preserved');
            const marker = path.join(fixture, phase + '.txt');
            const result = spawnSync('qs', ['-p', path.join(fixture, 'shell.qml')], {
                encoding: 'utf8', timeout: 15000,
                env: {...process.env, QT_QPA_PLATFORM: 'offscreen', DMS_AI_TEST_STATE: state, DMS_AI_TEST_RESULT: marker,
                    DMS_AI_TEST_PHASE: phase, DMS_AI_TEST_CONFIG: config},
            });
            assert.ifError(result.error);
            assert.equal(result.status, 0, result.stdout + result.stderr);
            assert.equal(fs.readFileSync(marker, 'utf8'), 'passed');
            const persisted = fs.readFileSync(path.join(state, 'session.json'), 'utf8');
            if (phase === 'corrupt') assert.equal(persisted, 'invalid JSON must be preserved');
            else assert.equal(JSON.parse(persisted).version, 4);
            const backups = fs.readdirSync(state).filter(name => name.startsWith('session-before-tabs-'));
            assert.equal(backups.length, 1);
            const backup = JSON.parse(fs.readFileSync(path.join(state, backups[0]), 'utf8'));
            assert.equal(backup.version, 3);
            assert.equal(backup.sessions['gemini|https://fixture.invalid'][0].content, 'legacy prompt');
        }
    } finally {
        fs.rmSync(fixture, {recursive: true});
    }
});
