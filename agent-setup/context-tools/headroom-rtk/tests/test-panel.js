const assert = require('node:assert/strict');
const { test } = require('node:test');
const { normalize, createPanel, show, start } = require('../headroom_rtk/panel.js');

class Element {
    constructor(tag) {
        this.tagName = tag;
        this.children = [];
        this.attributes = {};
        this.value = '';
    }
    setAttribute(name, value) { this.attributes[name] = value; }
    append(...children) {
        for (const child of children) {
            child.parentNode = this;
            this.children.push(child);
        }
    }
    insertBefore(child, anchor) {
        const index = this.children.indexOf(anchor);
        assert.notEqual(index, -1);
        child.parentNode = this;
        this.children.splice(index, 0, child);
    }
    set textContent(value) { this.value = value; this.children = []; }
    get textContent() { return this.value + this.children.map(child => child.textContent).join(' '); }
}

function documentFixture(compatible = true) {
    const main = new Element('main');
    const anchor = new Element('template');
    anchor.content = { querySelector: () => compatible ? new Element('div') : null };
    const native = new Element('div');
    native.textContent = 'Unchanged native Headroom metrics';
    main.append(native, anchor);
    function find(element, id) {
        if (element.id === id) return element;
        for (const child of element.children) {
            const found = find(child, id);
            if (found) return found;
        }
        return null;
    }
    return {
        main, anchor, native,
        createElement: tag => new Element(tag),
        querySelector: selector => selector === 'main > template[x-if="viewMode === \'session\'"]' ? anchor : null,
        getElementById: id => find(main, id),
    };
}

function payload(overrides = {}) {
    return {
        available: true,
        scope: 'retained_history',
        units: 'estimated_tokens_bytes_div_4',
        coverage: ['claude', 'codex'],
        summary: { total_commands: 4, total_input: 1000, total_output: 750, total_saved: 500, avg_savings_pct: 50 },
        ...overrides,
    };
}

test('Uses exact native estimates without adding Headroom or recomputing saved totals', () => {
    const panel = createPanel(documentFixture());
    show(panel, payload());
    assert.equal(panel.values.saved.textContent, '500');
    assert.equal(panel.values.flow.textContent, '1,000 → 750');
    assert.equal(panel.values.commands.textContent, '4');
    assert.equal(panel.values.percent.textContent, '50.0%');
    assert.match(panel.element.textContent, /RTK command output/);
    assert.match(panel.element.textContent, /Tracking history/);
    assert.match(panel.element.textContent, /excludes oversized outputs/);
    assert.match(panel.element.textContent, /bytes ÷ 4/);
    assert.match(panel.element.textContent, /Claude Code and Codex/);
    assert.match(panel.element.textContent, /Pi and Hermes/);
    assert.ok(!panel.element.textContent.includes('$'));
});

test('Zero counts are real zeroes, not missing data or NaN', () => {
    const panel = createPanel(documentFixture());
    show(panel, payload({ summary: { total_commands: 0, total_input: 0, total_output: 0, total_saved: 0, avg_savings_pct: 0 } }));
    assert.equal(panel.values.saved.textContent, '0');
    assert.equal(panel.values.flow.textContent, '0 → 0');
    assert.equal(panel.values.percent.textContent, '0.0%');
    assert.match(panel.status.textContent, /No RTK command executions/);
});

test('Unavailable, malformed, nonfinite, negative, or wrong-scope values never show invented totals', () => {
    const panel = createPanel(documentFixture());
    for (const data of [null, {}, payload({ available: false }), payload({ scope: 'session' }),
        payload({ units: 'usd' }), payload({ summary: {} }),
        payload({ summary: { ...payload().summary, total_saved: NaN } }),
        payload({ summary: { ...payload().summary, total_input: Infinity } }),
        payload({ summary: { ...payload().summary, total_commands: -1 } }),
        payload({ summary: { ...payload().summary, avg_savings_pct: 101 } }),
        payload({ summary: { ...payload().summary, total_saved: '<img onerror=alert(1)>' } })]) {
        assert.equal(normalize(data), null);
        show(panel, data);
        assert.equal(panel.values.saved.textContent, '—');
        assert.match(panel.status.textContent, /unavailable/);
        assert.ok(!/NaN|undefined|<img/.test(panel.element.textContent));
    }
});

test('Mounts one accessible card outside native views and polls only the same-origin endpoint', async () => {
    const doc = documentFixture();
    const requests = [], timers = [];
    const fetcher = async (...args) => { requests.push(args); return { ok: true, json: async () => payload() }; };
    const app = start(doc, fetcher, (...args) => timers.push(args));
    await app.refresh();
    assert.equal(doc.main.children[0], doc.native);
    assert.equal(doc.main.children[1], app.panel.element);
    assert.equal(doc.main.children[2], doc.anchor);
    assert.equal(doc.native.textContent, 'Unchanged native Headroom metrics');
    assert.equal(app.panel.element.attributes['aria-labelledby'], 'dotfiles-rtk-title');
    assert.equal(app.panel.status.attributes.role, 'status');
    assert.equal(timers.length, 1);
    assert.equal(timers[0][1], 15000);
    assert.equal(requests[0][0], '/dotfiles/rtk/stats');
    assert.deepEqual(requests[0][1], { cache: 'no-store', credentials: 'same-origin' });
    assert.equal(requests.length, 1);
    assert.equal(start(doc, fetcher, () => assert.fail('duplicate timer')), null);
});

test('Skips an incompatible dashboard without altering its native elements', () => {
    const doc = documentFixture(false);
    assert.equal(start(doc, () => assert.fail('must not fetch'), () => assert.fail('must not poll')), null);
    assert.equal(doc.main.children.length, 2);
});

test('Network and HTTP errors clear stale totals and preserve native dashboard content', async () => {
    for (const failure of [async () => { throw new Error('private backend detail'); }, async () => ({ ok: false })]) {
        const doc = documentFixture();
        let failing = false;
        const fetcher = async () => failing ? failure() : { ok: true, json: async () => payload() };
        const app = start(doc, fetcher, () => {});
        await app.refresh();
        assert.equal(app.panel.values.saved.textContent, '500');
        failing = true;
        await app.refresh();
        assert.equal(app.panel.values.saved.textContent, '—');
        assert.match(app.panel.status.textContent, /unavailable/);
        assert.ok(!app.panel.element.textContent.includes('private backend detail'));
        assert.equal(doc.native.textContent, 'Unchanged native Headroom metrics');
    }
});
