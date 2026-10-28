(() => {
    'use strict';

    const panelId = 'dotfiles-rtk-panel';

    function normalize(data) {
        if (!data || data.available !== true || data.scope !== 'retained_history'
            || data.units !== 'estimated_tokens_bytes_div_4') return null;
        const summary = data.summary;
        if (!summary || !['total_commands', 'total_input', 'total_output', 'total_saved']
            .every(key => Number.isSafeInteger(summary[key]) && summary[key] >= 0)) return null;
        if (!Number.isFinite(summary.avg_savings_pct)
            || summary.avg_savings_pct < 0 || summary.avg_savings_pct > 100) return null;
        return summary;
    }

    function element(doc, tag, classes, text) {
        const node = doc.createElement(tag);
        node.className = classes;
        if (text !== undefined) node.textContent = text;
        return node;
    }

    function createPanel(doc) {
        const card = element(doc, 'section', 'bg-surface rounded-lg p-4 border border-border mb-6');
        card.id = panelId;
        card.setAttribute('aria-labelledby', 'dotfiles-rtk-title');
        const title = element(doc, 'h2', 'text-sm font-medium text-gray-300', 'RTK command output');
        title.id = 'dotfiles-rtk-title';
        const scope = element(doc, 'p', 'text-xs text-gray-400 mt-1 mb-4',
            'Tracking history · global RTK totals, separate from the selected Headroom time view. RTK excludes oversized outputs from these totals.');
        const grid = element(doc, 'dl', 'grid grid-cols-2 gap-4 mb-4 md:grid-cols-4');
        const values = {};
        for (const [key, label] of [
            ['saved', 'Estimated tokens saved'],
            ['flow', 'Raw → filtered · estimated tokens'],
            ['commands', 'Command executions'],
            ['percent', 'Command output reduction'],
        ]) {
            const item = element(doc, 'div', 'min-w-0');
            const name = element(doc, 'dt', 'text-xs text-gray-400 mb-1', label);
            values[key] = element(doc, 'dd', 'font-mono text-lg tabular-nums text-gray-300 break-words', '—');
            item.append(name, values[key]);
            grid.append(item);
        }
        const status = element(doc, 'p', 'text-xs text-gray-400 mb-2', 'Loading RTK tracking history…');
        status.setAttribute('role', 'status');
        status.setAttribute('aria-live', 'polite');
        const units = element(doc, 'p', 'text-xs text-gray-400',
            'Token estimates use command output bytes ÷ 4. They do not measure prompt replays or bill savings.');
        const coverage = element(doc, 'p', 'text-xs text-gray-400 mt-1',
            'Automatic RTK filtering: Claude Code and Codex. Pi and Hermes currently use Headroom only.');
        card.append(title, scope, grid, status, units, coverage);
        return { element: card, values, status };
    }

    function show(panel, data) {
        const summary = normalize(data);
        if (!summary) {
            for (const value of Object.values(panel.values)) value.textContent = '—';
            panel.status.textContent = 'RTK data unavailable. Headroom metrics are unchanged.';
            return;
        }
        const number = value => value.toLocaleString('en-US');
        panel.values.saved.textContent = number(summary.total_saved);
        panel.values.flow.textContent = `${number(summary.total_input)} → ${number(summary.total_output)}`;
        panel.values.commands.textContent = number(summary.total_commands);
        panel.values.percent.textContent = `${summary.avg_savings_pct.toFixed(1)}%`;
        panel.status.textContent = summary.total_commands === 0
            ? 'No RTK command executions recorded. Updates every 15 seconds.'
            : 'Global RTK tracking history. Updates every 15 seconds.';
    }

    function start(doc, fetcher, repeat) {
        if (doc.getElementById(panelId)) return null;
        const anchor = doc.querySelector('main > template[x-if="viewMode === \'session\'"]');
        if (!anchor || !anchor.content.querySelector('[data-testid="session-optimization"]')) return null;
        const panel = createPanel(doc);
        anchor.parentNode.insertBefore(panel.element, anchor);
        let pending = null;
        async function refresh() {
            if (pending) return pending;
            pending = (async () => {
                try {
                    const response = await fetcher('/dotfiles/rtk/stats', {
                        cache: 'no-store', credentials: 'same-origin',
                    });
                    if (!response.ok) throw new Error('RTK stats unavailable');
                    show(panel, await response.json());
                } catch {
                    show(panel, null);
                }
            })();
            try { await pending; } finally { pending = null; }
        }
        refresh();
        repeat(refresh, 15000);
        return { panel, refresh };
    }

    if (typeof module !== 'undefined' && module.exports) {
        module.exports = { normalize, createPanel, show, start };
    }
    if (typeof document !== 'undefined') {
        const boot = () => start(document, window.fetch.bind(window), window.setInterval.bind(window));
        if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, { once: true });
        else boot();
    }
})();
