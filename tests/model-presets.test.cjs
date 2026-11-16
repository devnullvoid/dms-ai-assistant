const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

const presets = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../ModelPresets.js'), 'utf8').replace(/^\.pragma library\s*/, ''), presets);

test('migration seeds default model settings and omits credentials and endpoints', () => {
    const config = {model: 'fixture', temperature: 0.5, maxTokens: 1000, timeout: 30,
        geminiWebSearch: true, apiKey: 'secret-fixture', apiKeyEnvVar: 'SECRET', baseUrl: 'https://fixture.invalid'};
    const migrated = presets.restore(null, {gemini: config});
    assert.equal(migrated.gemini.selectedId, 'default');
    assert.equal(migrated.gemini.presets[0].values.model, 'fixture');
    assert.equal(migrated.gemini.presets[0].values.geminiWebSearch, true);
    assert.equal(JSON.stringify(migrated).includes('secret-fixture'), false);
    assert.equal(JSON.stringify(migrated).includes('apiKey'), false);
    assert.equal(JSON.stringify(migrated).includes('baseUrl'), false);
});

test('restored presets discard duplicate IDs/names and select a valid fallback', () => {
    const raw = {gemini: {selectedId: 'missing', presets: [
        null, 'invalid',
        {id: 'one', name: 'Research', values: {model: 'research', apiKey: 'secret'}},
        {id: 'one', name: 'Duplicate ID', values: {}},
        {id: 'two', name: ' research ', values: {}},
    ]}};
    const result = presets.restore(raw, {gemini: {model: 'fixture', temperature: 0.7, maxTokens: 1000, timeout: 30}});
    assert.equal(result.gemini.presets.length, 1);
    assert.equal(result.gemini.selectedId, 'one');
    assert.equal(result.gemini.presets[0].values.apiKey, undefined);
});

test('preset equality considers provider options and ignores credentials', () => {
    assert.equal(presets.same('gemini', {model: 'x', geminiWebSearch: true, apiKey: 'a'}, {model: 'x', geminiWebSearch: true, apiKey: 'b'}), true);
    assert.equal(presets.same('gemini', {model: 'x', geminiWebSearch: true}, {model: 'x', geminiWebSearch: false}), false);
    assert.equal(presets.same('inception', {model: 'x', inceptionReasoningEffort: 'high'}, {model: 'x', inceptionReasoningEffort: 'low'}), false);
});
