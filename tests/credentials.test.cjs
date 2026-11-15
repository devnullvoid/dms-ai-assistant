const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

const repo = path.join(__dirname, '..');

function methods(source) {
    return new Map(source.match(/^    function \w+\([^\n]*\) \{[\s\S]*?^    \}/gm)
        .map(method => [method.match(/function (\w+)/)[1], method]));
}

test('key editing and history isolation with synchronous settings reloads', () => {
    const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'dms-ai-credentials-'));
    try {
        const settings = fs.readFileSync(path.join(repo, 'AIAssistantSettings.qml'), 'utf8');
        const service = fs.readFileSync(path.join(repo, 'AIAssistantService.qml'), 'utf8');
        const chatMethods = methods(fs.readFileSync(path.join(repo, 'AIAssistant.qml'), 'utf8'));
        const serviceMethods = methods(service);
        const selected = ['defaultsForProvider', 'normalizedProfile', 'mergedProviders', 'syncLegacySnapshot',
            'loadSettings', 'setSessionApiKey', 'resolveApiKey', 'computeConfigHash', 'persistCurrentMessagesForHash',
            'switchConfigHistory', 'handleConfigChanged', 'loadMessages', 'saveSession', 'clearHistory', 'findLastUserText'];
        // Exercise actual controller methods and property bindings, with no
        // provider network calls or writes to the user's settings/history.
        const serviceProperties = service.match(/^    (?:readonly )?property [^\n]+/gm).join('\n');
        fs.writeFileSync(path.join(fixture, 'ServiceController.qml'), `
import QtQuick
import QtCore
import qs.Common
import qs.Services
import "TestEnvironment.js" as Quickshell
Item {
    id: root
    ${serviceProperties}
    property alias persistedSession: sessionFile.savedText
    QtObject { id: sessionFile; property string path: "fixture"; property string savedText: ""; function setText(text) { savedText = text; } }
    function refreshAvailableModels(force) {}
    onProviderChanged: handleConfigChanged()
    onBaseUrlChanged: handleConfigChanged()
    Connections { target: PluginService; function onPluginDataChanged(pId) { if (pId === root.pluginId) root.loadSettings(); } }
    ${selected.map(name => serviceMethods.get(name)).join('\n')}
}`);
        fs.writeFileSync(path.join(fixture, 'ChatController.qml'), `
import QtQuick
import qs.Common
Item {
    required property var aiService
    property bool showNewChatConfirm: false
    property string transientHint: ""
    QtObject { id: hintResetTimer; function restart() {} }
    ${['showTemporaryHint', 'startNewChat', 'confirmClearHistory'].map(name => chatMethods.get(name)).join('\n')}
}`);
        const fieldStart = settings.indexOf('                                DankTextField {\n                                    id: apiKeyField');
        const fieldEnd = settings.indexOf('\n                                DankButton {', fieldStart);
        assert.ok(fieldStart >= 0 && fieldEnd > fieldStart);
        const field = settings.slice(fieldStart, fieldEnd);
        const settingsProperties = settings.slice(settings.indexOf('    required property var aiService'), settings.indexOf('    function save('));
        fs.writeFileSync(path.join(fixture, 'SettingsController.qml'), `
import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Services
Item {
    id: root
    ${settingsProperties}
    ${Array.from(methods(settings).values()).join('\n')}
    ${field}
    Connections { target: PluginService; function onPluginDataChanged(pId) { if (pId === root.pluginId) root.load(); } }
}`);
        fs.writeFileSync(path.join(fixture, 'DankTextField.qml'), `import QtQuick.Controls
TextField {
    property string leftIconName: ""
    // DMS's DTextField forwards textChanged, including programmatic updates.
    onTextChanged: textEdited()
}`);
        fs.writeFileSync(path.join(fixture, 'TestEnvironment.js'), '.pragma library\nfunction env(name) { return ""; }\n');
        fs.mkdirSync(path.join(fixture, 'qs/Common'), {recursive: true});
        fs.writeFileSync(path.join(fixture, 'qs/Common/qmldir'), 'module qs.Common\nsingleton Paths 1.0 Paths.qml\nsingleton I18n 1.0 I18n.qml\n');
        fs.writeFileSync(path.join(fixture, 'qs/Common/Paths.qml'), 'pragma Singleton\nimport QtQuick\nQtObject { function strip(value) { return String(value); } }\n');
        fs.writeFileSync(path.join(fixture, 'qs/Common/I18n.qml'), 'pragma Singleton\nimport QtQuick\nQtObject { function tr(value) { return value; } }\n');
        fs.mkdirSync(path.join(fixture, 'qs/Services'), {recursive: true});
        fs.writeFileSync(path.join(fixture, 'qs/Services/qmldir'), 'module qs.Services\nsingleton PluginService 1.0 PluginService.qml\n');
        fs.writeFileSync(path.join(fixture, 'qs/Services/PluginService.qml'), `pragma Singleton
import QtQuick
QtObject {
    property var data: ({})
    signal pluginDataChanged(string pluginId)
    function reset() {
        data = {provider: "gemini", providers: {
            gemini: {apiKey: "old-gemini-fixture", saveApiKey: true},
            anthropic: {apiKey: "anthropic-fixture", saveApiKey: true}
        }};
    }
    function loadPluginData(id, key, fallback) { return data[key] === undefined ? fallback : data[key]; }
    function savePluginData(id, key, value) {
        const next = JSON.parse(JSON.stringify(data));
        next[key] = JSON.parse(JSON.stringify(value));
        data = next;
        pluginDataChanged(id);
    }
}`);
        fs.copyFileSync(path.join(__dirname, 'tst_Credentials.qml'), path.join(fixture, 'tst_Credentials.qml'));
        const result = spawnSync(process.env.QML_TEST_RUNNER || '/usr/lib/qt6/bin/qmltestrunner',
            ['-input', fixture, '-import', fixture, '-o', '-,txt'], {
                encoding: 'utf8', timeout: 30000,
                env: {...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software'},
            });
        assert.ifError(result.error);
        assert.equal(result.status, 0, result.stdout + result.stderr);
        console.log(result.stdout.split('\n').filter(line => /^(PASS|FAIL|Totals)/.test(line)).join('\n'));
    } finally {
        fs.rmSync(fixture, {recursive: true});
    }
});
