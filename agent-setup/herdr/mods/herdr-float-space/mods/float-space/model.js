export const STATE_KEY = "float-space.v1";
export const MAX_TERMINALS = 12;
export const DEFAULT_SIZE = { width: 0.50, height: 0.60 };
// One click sizes: a small window for notes or a quick command, the default,
// and room for an agent.
export const PRESETS = [
  { id: "small", label: "Small", width: 0.20, height: 0.50 },
  { id: "normal", label: "Normal", ...DEFAULT_SIZE },
  { id: "large", label: "Large", width: 0.85, height: 0.88 },
];

function fraction(value, fallback, min, max) {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.round(Math.min(max, Math.max(min, value)) * 100) / 100 : fallback;
}

export function readSize(value) {
  return {
    width: fraction(value?.width, DEFAULT_SIZE.width, 0.20, 0.95),
    height: fraction(value?.height, DEFAULT_SIZE.height, 0.30, 0.95),
  };
}

export function ownedTerminals(terminals, appHome) {
  return terminals.filter(terminal => /^t[0-9a-z]+$/.test(terminal.address ?? "")
    && terminal.state === "live"
    && terminal.labels?.["herdr.mod"] === "float-space"
    && terminal.labels?.["herdr.float-space"] === appHome);
}

export function readState(value) {
  if (value?.version > 2) {
    throw new Error("Float Space data belongs to a newer version. Update the mod before opening it.");
  }
  const seen = new Set();
  const tabs = (Array.isArray(value?.tabs) ? value.tabs : []).filter(tab => {
    if (!/^t[0-9a-z]+$/.test(tab?.address ?? "") || seen.has(tab.address)) return false;
    seen.add(tab.address);
    return true;
  }).map((tab, i) => ({ address: tab.address, title: String(tab.title || `Terminal ${i + 1}`) }));
  const size = readSize(value?.size);
  return {
    version: 2,
    tabs,
    active: tabs.some(tab => tab.address === value?.active) ? value.active : tabs[0]?.address ?? null,
    notes: typeof value?.notes === "string" ? value.notes : "",
    page: value?.page === "notes" ? "notes" : "terminal",
    size,
    sequence: Math.max(tabs.length, Number.isSafeInteger(value?.sequence) ? value.sequence : 0),
  };
}

function path(value) {
  return typeof value === "string" && value !== "" ? value : null;
}

// The directory the open space is actually in. Herdr's stored space folder is
// only where its terminals started, and it stays there after a cd. A new tab
// in Herdr uses the focused terminal's live folder instead. Clicking into
// this window reports that scratch shell (no pane), so that cwd is ignored
// and the space's own pane is used.
function liveFolder(space, focus, panes) {
  if (focus?.pane && focus.space === space.id) {
    const cwd = path(focus.cwd);
    if (cwd) return cwd;
  }
  const tabs = Array.isArray(space.tabs) ? space.tabs : [];
  const tabIds = new Set(tabs.map(tab => tab.id));
  const active = tabs.find(tab => tab.active);
  const list = (Array.isArray(panes) ? panes : []).filter(pane =>
    pane && tabIds.has(pane.tab) && path(pane.cwd));
  const shown = active ? list.filter(pane => pane.tab === active.id) : list;
  const pool = shown.length ? shown : list;
  return path((pool.find(pane => pane.focused) ?? pool[0])?.cwd);
}

// Where a new shell starts. A remote space's path is on another machine, so
// the shell starts at home here. With no live folder, the space's own start
// folder, then home.
export function startFolder(spaces, focus, homeDir, panes) {
  const list = Array.isArray(spaces) ? spaces : [];
  const space = focus?.space
    ? list.find(item => item?.id === focus.space)
    : list.find(item => item?.active);
  if (!space || space.machine) return homeDir;
  return liveFolder(space, focus, panes) ?? path(space.folder) ?? homeDir;
}

// A new shell takes the lowest number no open tab uses, as Herdr numbers its
// tabs: closing Terminal 2 frees "Terminal 2" for the next one.
export function nextTitle(tabs) {
  const used = new Set(tabs.map(tab => /^Terminal (\d+)$/.exec(tab.title)?.[1]).filter(Boolean).map(Number));
  let number = 1;
  while (used.has(number)) number += 1;
  return `Terminal ${number}`;
}

// Agent changes worth telling the person about, given the statuses seen last
// time (null: nothing seen yet, so this only takes note). Finishing is working
// → idle or done; blocked and error need them. `lookingAt` is the terminal
// they're watching, which never alerts.
export function agentAlerts(previous, terminals, lookingAt) {
  const statuses = {};
  const alerts = [];
  for (const terminal of terminals) {
    const now = terminal.status ?? null;
    statuses[terminal.address] = now;
    const before = previous?.[terminal.address];
    if (before === undefined || before === now || terminal.address === lookingAt) continue;
    if (now === "blocked" || now === "error") alerts.push({ address: terminal.address, kind: now });
    else if (before === "working" && (now === "idle" || now === "done")) alerts.push({ address: terminal.address, kind: "done" });
  }
  return { statuses, alerts };
}

// Only accept terminals returned by the core's exact ownership-label query.
// A saved address by itself never authorizes showing or killing a terminal.
export function reconcile(state, owned) {
  const addresses = new Set(owned.map(terminal => terminal.address));
  const tabs = state.tabs.filter(tab => addresses.has(tab.address));
  const known = new Set(tabs.map(tab => tab.address));
  let sequence = state.sequence;
  for (const terminal of owned) {
    if (!/^t[0-9a-z]+$/.test(terminal.address) || known.has(terminal.address)) continue;
    tabs.push({ address: terminal.address, title: nextTitle(tabs) });
    sequence += 1;
    known.add(terminal.address);
  }
  return {
    ...state, tabs, sequence,
    active: tabs.some(tab => tab.address === state.active) ? state.active : tabs[0]?.address ?? null,
  };
}

export function returnPane(previous, current, panes, owned) {
  const available = panes.filter(pane => pane.tab === current?.tab);
  if (available.some(pane => pane.pane === current?.pane)) return current.pane;
  if (current?.terminal && !owned.includes(current.terminal)) return null;
  if (previous?.tab === current?.tab && available.some(pane => pane.pane === previous.pane)) return previous.pane;
  return available.find(pane => pane.focused)?.pane ?? available[0]?.pane ?? null;
}

// Whether a press landed in the window, given its header's bounds and the
// window's height, both in window pixels. The 1px border counts.
export function pressedInWindow(position, bar, height) {
  return position.x >= bar.x - 1 && position.x <= bar.x + bar.width + 1
    && position.y >= bar.y - 1 && position.y <= bar.y - 1 + height;
}

// The terminal a window shows; null when it shows Notes.
export function shownTerminal(state) {
  return state.page === "terminal" ? state.active : null;
}

// Agents show their own name, as in Herdr's tab bar; shells keep their tab title.
export function tabName(tab, terminal) {
  return terminal?.program?.agent ? terminal.program.name : tab.title;
}

// `generation` tells the header which mount it belongs to, so it can tell a
// close it didn't ask for (Herdr's) from a replacement.
export function windowSpec(state, generation = 0) {
  const address = shownTerminal(state);
  const body = address
    ? { id: "float-space-terminal", type: "block", content: { terminal: address } }
    : { id: "float-space-notes", type: "block", content: { mod: "float-space", props: { role: "notes" } } };
  // Herdr reopens a key where it was dropped, even when a taller size no longer
  // fits there. Each size has its own key: a new one opens centered, and each
  // keeps its own spot.
  const key = `float-space.window.${Math.round(state.size.width * 100)}x${Math.round(state.size.height * 100)}`;
  // A layout's border can't change color without replacing the window, so the
  // mod draws its own, accent while the keyboard is in the window: the header
  // its top, 1px blocks the sides, a 10px band the bottom and its corners.
  // The layout's 10px corners clip them like a pane card's.
  const edge = (side, px) => ({ id: `float-space-edge-${side}`, type: "block", size: { px },
    content: { mod: "float-space", props: { role: "edge", side } } });
  return {
    kind: "window", key, frame: "none",
    width: state.size.width, height: state.size.height,
    layout: {
      id: "float-space-window", type: "column", background: "background", radius: 10, resizable: false,
      children: [
        { id: "float-space-chrome", type: "block", size: { px: 30 }, content: { mod: "float-space", props: { role: "bar", generation } } },
        { id: "float-space-body", type: "row", resizable: false, children: [edge("left", 1), body, edge("right", 1)] },
        edge("bottom", 10),
      ],
    },
  };
}
