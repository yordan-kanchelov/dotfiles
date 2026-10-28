// Exercise methods extracted from the actual Headroom dashboard template.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { test } = require('node:test');

if (process.argv.length !== 4 || process.argv[2] !== '--source') {
    console.error('Usage: node scripts/test-headroom-transformations-ui.js --source dashboard.html');
    process.exit(2);
}
const source = fs.readFileSync(process.argv[3], 'utf8');
const document = {
    createElement() {
        return {
            textContent: '',
            get innerHTML() {
                return String(this.textContent).replace(/&/g, '&amp;')
                    .replace(/</g, '&lt;').replace(/>/g, '&gt;');
            },
        };
    },
};
const dashboard = { feedItemHeight: 160 };
for (const name of ['formatTransformationSnapshot', 'renderTransformationCard', 'escapeHtml']) {
    const start = source.indexOf(`                ${name}(`);
    if (start === -1 && name === 'formatTransformationSnapshot') continue;
    assert.notEqual(start, -1, `Dashboard method not found: ${name}`);
    const end = source.indexOf('\n                },', start);
    assert.notEqual(end, -1, `Dashboard method is incomplete: ${name}`);
    const method = source.slice(start, end) + '\n                }';
    dashboard[name] = vm.runInNewContext(`({${method}})`, { document })[name];
}

function render(before, after, response = 'MODEL_REPLY_MUST_NOT_APPEAR') {
    return dashboard.renderTransformationCard({
        request_messages: before,
        compressed_messages: after,
        response_content: response,
    }, 0);
}

function pane(html, side) {
    const match = html.match(new RegExp(`<div class="diff-${side} ([^>]*)>([\\s\\S]*?)</div>`));
    assert.ok(match, `${side} pane is present`);
    return match[2];
}

test('Before and After show distinct request snapshots, never a model reply', () => {
    const html = render('before line one\nline two', 'compressed request');
    assert.equal(pane(html, 'before'), 'before line one\nline two');
    assert.equal(pane(html, 'after'), 'compressed request');
    assert.ok(!html.includes('MODEL_REPLY_MUST_NOT_APPEAR'));
    assert.equal((html.match(/white-space: pre-wrap; overflow-wrap: anywhere;/g) || []).length, 2);
});

test('Anthropic content blocks preserve text, tool calls, and tool results', () => {
    const messages = [{ role: 'assistant', content: [
        { type: 'text', text: 'inspect files' },
        { type: 'tool_use', id: 'tool-1', name: 'Bash', input: { command: 'git status' } },
    ] }, { role: 'user', content: [
        { type: 'tool_result', tool_use_id: 'tool-1', content: 'working tree clean' },
    ] }];
    const html = render(messages, messages);
    for (const side of ['before', 'after']) {
        assert.equal(pane(html, side), JSON.stringify(messages, null, 2));
        assert.ok(!pane(html, side).includes('[object Object]'));
    }
});

test('Responses input items preserve function calls and outputs without content fields', () => {
    const input = [
        { role: 'user', content: [{ type: 'input_text', text: 'inspect status' }] },
        { type: 'function_call', call_id: 'call-1', name: 'exec_command', arguments: '{"cmd":"git status"}' },
        { type: 'function_call_output', call_id: 'call-1', output: 'working tree clean' },
    ];
    const html = render(input, input);
    assert.equal(pane(html, 'before'), JSON.stringify(input, null, 2));
    assert.equal(pane(html, 'after'), JSON.stringify(input, null, 2));
});

test('Snapshot HTML is escaped on both sides', () => {
    const html = render('<script>before & bad</script>', [{ content: '<img src=x onerror=alert(1)>' }]);
    assert.equal(pane(html, 'before'), '&lt;script&gt;before &amp; bad&lt;/script&gt;');
    assert.ok(pane(html, 'after').includes('&lt;img src=x onerror=alert(1)&gt;'));
    assert.ok(!html.includes('<script>') && !html.includes('<img '));
});

test('Missing snapshots have independent placeholders; captured empty arrays stay visible', () => {
    const missing = 'No message snapshot captured for this request.';
    const onlyBefore = render([], null);
    assert.equal(pane(onlyBefore, 'before'), '[]');
    assert.ok(pane(onlyBefore, 'after').includes(missing));
    const onlyAfter = render(undefined, []);
    assert.ok(pane(onlyAfter, 'before').includes(missing));
    assert.equal(pane(onlyAfter, 'after'), '[]');
    const neither = render(null, undefined);
    assert.equal((neither.match(/No message snapshot captured for this request\./g) || []).length, 2);
    assert.ok(!neither.includes('Enable HEADROOM_LOG_MESSAGES'));
    assert.ok(!neither.includes('MODEL_REPLY_MUST_NOT_APPEAR'));
});

test('Previews retain the 2000-character cap and explicitly mark truncation', () => {
    const prefix = 'x'.repeat(2000);
    const html = render(prefix + 'HIDDEN_TAIL', 'short');
    assert.equal(pane(html, 'before'), prefix + '\n\n[preview truncated at 2000 characters]');
    assert.equal(pane(html, 'after'), 'short');
    assert.ok(!html.includes('HIDDEN_TAIL'));
    assert.equal(pane(render(prefix, prefix), 'before'), prefix);
});
