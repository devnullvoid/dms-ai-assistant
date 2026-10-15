const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync, execFileSync } = require('node:child_process');
const { test } = require('node:test');

test('MessageList honors wheel/scrollbar navigation during streaming and layout changes', () => {
    const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'dms-ai-scrolling-'));
    try {
        fs.mkdirSync(path.join(fixture, 'qs/Common'), { recursive: true });
        fs.writeFileSync(path.join(fixture, 'qs/Common/qmldir'), 'module qs.Common\nsingleton Theme 1.0 Theme.qml\n');
        fs.copyFileSync(path.join(__dirname, 'Theme.qml'), path.join(fixture, 'qs/Common/Theme.qml'));
        if (process.env.SCROLLING_BASELINE_REF) {
            const source = execFileSync('git', ['show', process.env.SCROLLING_BASELINE_REF + ':MessageList.qml'], {cwd: path.join(__dirname, '..'), encoding: 'utf8'});
            // Give the old controls the same test identifiers; behavior is unchanged.
            fs.writeFileSync(path.join(fixture, 'MessageList.qml'), source
                .replace('id: listView', 'id: listView\n        objectName: "messageListView"')
                .replace('ScrollBar.vertical: ScrollBar { }', 'ScrollBar.vertical: ScrollBar { objectName: "messageScrollBar" }'));
        } else {
            fs.copyFileSync(path.join(__dirname, '../MessageList.qml'), path.join(fixture, 'MessageList.qml'));
        }
        for (const file of ['MessageBubble.qml', 'tst_Scrolling.qml'])
            fs.copyFileSync(path.join(__dirname, file), path.join(fixture, file));
        const runner = process.env.QML_TEST_RUNNER || '/usr/lib/qt6/bin/qmltestrunner';
        const result = spawnSync(runner, ['-input', fixture, '-import', fixture, '-o', '-,txt'], {
            encoding: 'utf8', timeout: 30000,
            env: { ...process.env, QT_QPA_PLATFORM: 'offscreen', QT_QUICK_BACKEND: 'software' },
        });
        assert.ifError(result.error);
        assert.equal(result.status, 0, result.stdout + result.stderr);
        console.log(result.stdout.split('\n').filter(line => /^(PASS|FAIL|Totals)/.test(line)).join('\n'));
    } finally {
        fs.rmSync(fixture, { recursive: true });
    }
});
