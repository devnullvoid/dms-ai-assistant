const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { test } = require('node:test');

test('conversation tabs respond to selection, rename, close, add and overflow', () => {
    const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'dms-ai-tab-ui-'));
    try {
        fs.copyFileSync(path.join(__dirname, '../ConversationTabs.qml'), path.join(fixture, 'ConversationTabs.qml'));
        fs.copyFileSync(path.join(__dirname, 'tst_ConversationTabs.qml'), path.join(fixture, 'tst_ConversationTabs.qml'));
        fs.mkdirSync(path.join(fixture, 'qs/Common'), {recursive: true});
        fs.writeFileSync(path.join(fixture, 'qs/Common/qmldir'), 'module qs.Common\nsingleton Theme 1.0 Theme.qml\nsingleton I18n 1.0 I18n.qml\n');
        fs.writeFileSync(path.join(fixture, 'qs/Common/Theme.qml'), `pragma Singleton
import QtQuick
QtObject {
    readonly property int spacingXS: 4
    readonly property int spacingS: 8
    readonly property int spacingM: 16
    readonly property int cornerRadius: 8
    readonly property int fontSizeSmall: 14
    readonly property string fontFamily: "Sans"
    readonly property color surfaceVariant: "#555555"
    readonly property color surfaceContainerHigh: "#333333"
    readonly property color outlineMedium: "#777777"
    readonly property color surfaceText: "white"
    readonly property color primary: "blue"
    property color onPrimary
    Component.onCompleted: { onPrimary = "white"; }
}`);
        fs.writeFileSync(path.join(fixture, 'qs/Common/I18n.qml'), 'pragma Singleton\nimport QtQuick\nQtObject { function tr(value) { return value; } }\n');
        fs.mkdirSync(path.join(fixture, 'qs/Widgets'), {recursive: true});
        fs.writeFileSync(path.join(fixture, 'qs/Widgets/qmldir'), 'module qs.Widgets\nDankIcon 1.0 DankIcon.qml\nDankActionButton 1.0 DankActionButton.qml\n');
        fs.writeFileSync(path.join(fixture, 'qs/Widgets/DankIcon.qml'), 'import QtQuick\nText { property string name: ""; property int size: 14; text: "×"; font.pixelSize: size }\n');
        fs.writeFileSync(path.join(fixture, 'qs/Widgets/DankActionButton.qml'), `import QtQuick
Item {
    property string iconName: ""
    property string tooltipText: ""
    property int buttonSize: 32
    width: buttonSize
    height: buttonSize
    signal clicked()
    MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
}`);
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
