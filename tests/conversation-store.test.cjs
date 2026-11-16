const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const store = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../ConversationStore.js'), 'utf8').replace(/^\.pragma library\s*/, ''), store);
const message = content => ({role: 'user', content, id: content, status: 'ok'});

test('v3 provider histories migrate without losing other providers', () => {
    const groups = store.restore({version: 3, sessions: {gemini: [message('First prompt')], anthropic: [message('Other prompt')]}}, 'gemini', 50);
    assert.equal(groups.gemini.tabs[0].messages[0].content, 'First prompt');
    assert.equal(groups.gemini.tabs[0].title, 'First prompt');
    assert.equal(groups.anthropic.tabs[0].messages[0].content, 'Other prompt');
});

test('v2 histories retain every model as a tab, including the active model', () => {
    const groups = store.restore({version: 2, providerConfigHash: 'gemini|https://host|model-b', sessions: {
        'gemini|https://host|model-a': [message('A')], 'gemini|https://host|model-b': [message('B')],
    }}, 'gemini|https://host', 50);
    const group = groups['gemini|https://host'];
    assert.equal(group.tabs.length, 2);
    assert.equal(group.tabs.find(tab => tab.id === group.activeId).messages[0].content, 'B');
});

test('v1 single-chat history migrates to its provider endpoint', () => {
    const groups = store.restore({providerConfigHash: 'gemini|https://host|model', messages: [message('legacy')]}, 'other', 50);
    assert.equal(groups['gemini|https://host'].tabs[0].messages[0].content, 'legacy');
});

test('v4 restores active selection, names and drafts while excluding unfinished responses', () => {
    const groups = store.restore({version: 4, conversationGroups: {gemini: {activeId: 'second', tabs: [
        {id: 'first', title: 'Research', customTitle: true, draft: 'unfinished', messages: [message('old'), message('new')]},
        {id: 'second', title: 'Second', draft: '', messages: [{role: 'assistant', content: 'partial', status: 'streaming'}]},
    ]}}}, 'gemini', 1);
    assert.equal(groups.gemini.activeId, 'second');
    assert.equal(groups.gemini.tabs[0].title, 'Research');
    assert.equal(groups.gemini.tabs[0].draft, 'unfinished');
    assert.equal(groups.gemini.tabs[0].messages.length, 1);
    assert.equal(groups.gemini.tabs[1].messages.length, 0);
});

test('malformed or unknown history is rejected rather than converted to empty history', () => {
    for (const data of [null, [], {}, {version: 5}, {version: 3, sessions: {bad: 'not messages'}},
        {version: 4, conversationGroups: {bad: {tabs: []}}}])
        assert.throws(() => store.restore(data, 'gemini', 50));
});
