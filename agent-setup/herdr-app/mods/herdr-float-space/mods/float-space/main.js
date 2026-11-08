import { View, div, svg, image } from "gpui-kit";
import { HoverCard, h_flex, v_flex, TextareaState, Textarea, InputState, Input, SliderState, Slider, SliderTrack, SliderIndicator, SliderThumb } from "gpui-base";
import { appHome, home, hc, focused, spaces, panes, terminals, shared, setShared, settings, props, theme, run, openOverlay, closeOverlay, notify, playSound, nextCommand, readTextFile, writeTextFile, window as app } from "herdr";
import { STATE_KEY, DEFAULT_SIZE, MIN_SIZE, MAX_SIZE, PRESETS, sameSize, readState, ownedTerminals, tabName, tabProgram, liveStatus, pressedInWindow, agentAlerts, unseenFinishes, tabStatus, startFolder } from "./model.js";
import { MAX_NOTES, NOTE_COLORS, notesPath, parseNotes, serializeNotes, firstNotes, adoptLegacy, activeNote, nextNoteName, addNote, renameNote, removeNote, selectNote, setNoteText, setNoteColor, noteColor } from "./notes.js";
import { FloatController } from "./controller.js";

const WINDOW = "__herdr_float_space_window_v1";
const SIZE_POPUP = "__herdr_float_space_size_v1";
const NOTES = "__herdr_float_space_notes_v1";
const NOTES_MENU = "__herdr_float_space_notes_menu_v1";

function resultJSON(result, operation) {
  if (result.code !== 0) throw new Error(`${operation}: ${result.stderr.trim() || `exit ${result.code}`}`);
  try { return JSON.parse(result.stdout); }
  catch { throw new Error(`${operation}: invalid response from herdr-core`); }
}

function host() {
  const labels = ["--label", "herdr.mod=float-space", "--label", `herdr.float-space=${appHome()}`];
  return {
    getState: () => shared(STATE_KEY),
    setState: state => setShared(STATE_KEY, state),
    focused, panes, terminals,
    liveOwned: () => ownedTerminals(terminals(), appHome()),
    listOwned: async () => {
      const data = resultJSON(await hc(["ls", "--json", ...labels]), "List Float Space terminals");
      if (!Array.isArray(data.terminals)) throw new Error("List Float Space terminals: missing terminal list");
      return data.terminals;
    },
    spawnOwned: async () => resultJSON(await hc(["run", "--bg", "--keep", "--no-parent", "--cwd", startFolder(spaces(), focused(), home(), panes()), "--json", ...labels]), "Start terminal"),
    killOwned: async address => {
      const result = await hc(["kill", address]);
      if (result.code !== 0) throw new Error(result.stderr.trim() || "Could not end terminal");
    },
    open: spec => openOverlay(spec),
    close: id => closeOverlay(id),
    focusPane: pane => run("pane.focus", { pane }),
  };
}

// No copy lives as long as the window, so every copy shares this controller.
// Its fields outlive copies and reloads; its methods are this build's.
function windowShared() {
  const memory = globalThis[WINDOW] ??= { controller: new FloatController(), lease: null };
  Object.setPrototypeOf(memory.controller, FloatController.prototype);
  return memory;
}

// Each command runs in its own invisible copy, which closes itself when done.
// Herdr stops a copy's tasks when that copy closes or reloads, and a remount
// closes the header, so neither the header nor a popup may run one. The
// shortcut's `mod.open` starts the same copy without a command: a toggle.
function act(command) {
  openOverlay({ mod: "float-space", kind: "window", frame: "none", width: 1, height: 1, props: { role: "run", command } });
}

// One command at a time. A claim, not a shared promise chain: a chain through
// a copy Herdr stopped never settles, while a stopped copy's claim expires.
async function claim(cx, owner) {
  const memory = windowShared();
  while (memory.lease && memory.lease.owner !== owner && Date.now() - memory.lease.at < 15000) await cx.sleep(15);
  memory.lease = { owner, at: Date.now() };
}

function release(owner) {
  const memory = windowShared();
  if (memory.lease?.owner === owner) memory.lease = null;
}

async function executeCommand(command, owner, cx) {
  try {
    await claim(cx, owner);
    await windowShared().controller.handle(command, host());
  } catch (error) {
    notify({ title: "Float Space", body: String(error?.message ?? error), level: "error" });
  } finally {
    release(owner);
    closeOverlay(owner);
  }
}

function stop(_event, cx) { cx.stop_propagation(); }

// The header and the edge blocks draw one border. Each waits on the same
// change in a task of its own (a task's `cx.notify()` redraws its view even
// when another view woke it), so all four redraw together.
function showFocus(keyboard) {
  const memory = windowShared();
  if (memory.keyboard === keyboard) return;
  memory.keyboard = keyboard;
  memory.focusChanged?.resolve();
  memory.focusChanged = null;
}

function drawsBorder(cx) {
  cx.spawn(async cx => {
    for (;;) {
      const memory = windowShared();
      if (!memory.focusChanged) {
        let resolve;
        const promise = new Promise(done => { resolve = done; });
        memory.focusChanged = { promise, resolve };
      }
      await memory.focusChanged.promise;
      cx.notify();
    }
  });
}

// Notes, in memory for every copy and across reloads like the controller, and
// in the mod's own file. `disk` is that file as last read or written:
// undefined before the first read, null while there is none.
function notesMemory() {
  return globalThis[NOTES] ??= { doc: null, disk: undefined, tried: [], loading: 0, error: null, signal: null, focus: false, warned: 0 };
}

function notesFile() {
  return notesPath(appHome());
}

// Saving failures repeat on every pause in typing: one toast per 10 s.
function notesProblem(body, level) {
  const memory = notesMemory();
  if (Date.now() - memory.warned < 10000) return;
  memory.warned = Date.now();
  notify({ title: "Float Space", body, level });
}

// The header, Notes and the menu each wait on this in a task of their own,
// as the border's blocks do.
function notesChanged() {
  const memory = notesMemory();
  memory.signal?.resolve();
  memory.signal = null;
}

function followsNotes(cx, react) {
  cx.spawn(async cx => {
    for (;;) {
      const memory = notesMemory();
      if (!memory.signal) {
        let resolve;
        const promise = new Promise(done => { resolve = done; });
        memory.signal = { promise, resolve };
      }
      await memory.signal.promise;
      react?.(cx);
      cx.notify();
    }
  });
}

// Writes the notes when they differ from the file. A write runs on a thread
// of its own and lands even when the copy that started it is stopped, and two
// writes may race; the file's expected text settles both. A file that turns
// out to hold one of this app's recent writes is no news; anything else was
// edited elsewhere, and the notes shown here win.
async function flushNotes() {
  const memory = notesMemory();
  for (let round = 0; round < 3 && memory.doc && memory.disk !== undefined; round += 1) {
    const text = serializeNotes(memory.doc);
    const expected = memory.disk;
    if (text === expected) return;
    memory.tried = [...memory.tried.slice(-7), text];
    try {
      await writeTextFile(notesFile(), text, expected);
      if (memory.disk === expected) memory.disk = text;
      return;
    } catch (error) {
      const now = await readTextFile(notesFile()).catch(() => undefined);
      if (now === undefined || now === expected) {
        notesProblem(`Could not save notes: ${String(error?.message ?? error)}`, "error");
        return;
      }
      if (now !== null && !memory.tried.includes(now)) {
        notesProblem("Kept these notes over an outside edit of notes.json.", "warning");
      }
      if (memory.disk === expected) memory.disk = now;
    }
  }
}

// Changes the notes in memory at once, then saves them. `quiet`: only a
// note's text changed, which only the editor shows.
function changeNotes(update, quiet = false) {
  const memory = notesMemory();
  if (!memory.doc) return Promise.resolve();
  const next = update(memory.doc);
  if (next === memory.doc) return Promise.resolve();
  memory.doc = next;
  if (!quiet) notesChanged();
  return flushNotes();
}

// Earlier versions kept one Notes page in shared state.
function forgetLegacyNotes() {
  const state = shared(STATE_KEY);
  if (!state || typeof state !== "object" || !("notes" in state)) return;
  const { notes: _moved, ...rest } = state;
  setShared(STATE_KEY, rest);
}

// One read per app run, shared by the copies that need it; a read that a
// stopped copy left unfinished expires. The first read moves the Notes page
// out of shared state, and shared state forgets it only once the file has it.
async function ensureNotes(cx) {
  const memory = notesMemory();
  while (!memory.doc && memory.loading && Date.now() - memory.loading < 3000) await cx.sleep(15);
  if (memory.doc) return memory.doc;
  if (memory.error && Date.now() - memory.error.at < 2000) return null;
  memory.loading = Date.now();
  try {
    const text = await readTextFile(notesFile());
    if (memory.doc) return memory.doc;
    const legacy = shared(STATE_KEY)?.notes;
    const { doc, kept } = text === null ? { doc: firstNotes(legacy), kept: true } : adoptLegacy(parseNotes(text), legacy);
    const unwritten = serializeNotes(doc) !== text;
    memory.disk = text;
    memory.doc = doc;
    memory.error = null;
    await flushNotes();
    if (kept && (!unwritten || memory.disk !== text)) forgetLegacyNotes();
  } catch (error) {
    memory.error = { message: String(error?.message ?? error), at: Date.now() };
  } finally {
    memory.loading = 0;
    notesChanged();
  }
  return memory.doc;
}

// Picks up an edit made outside Float Space (an agent, an editor) while
// nothing typed here waits to be saved.
async function refreshNotes() {
  const memory = notesMemory();
  const known = memory.disk;
  if (!memory.doc || typeof known !== "string" || serializeNotes(memory.doc) !== known) return;
  const text = await readTextFile(notesFile()).catch(() => undefined);
  if (typeof text !== "string" || text === known || memory.disk !== known || serializeNotes(memory.doc) !== known) return;
  let doc;
  try { doc = parseNotes(text); }
  catch { return; }
  memory.doc = doc;
  memory.disk = text;
  notesChanged();
}

// Herdr alerts only for agents in its spaces, so Float Space tells about its
// own the way Herdr does: Herdr's sound, and Herdr's agent toast unless
// they're watching it (Herdr's window active, the keyboard in this window,
// that tab shown). The header checks while the window is open, the
// status-bar button also while it's hidden; the shared memory makes one of
// them report each change. The same check keeps the button's dot.
const ALERTS = {
  done: { says: "finished", level: "info" },
  blocked: { says: "needs you", level: "error" },
};
function watchAgents() {
  const memory = windowShared();
  const state = readState(shared(STATE_KEY));
  const live = ownedTerminals(terminals(), appHome());
  // After a gap (hidden with no button, reloaded), what changed meanwhile is old news.
  const seen = Date.now() - (memory.watchedAt ?? 0) < 3000 ? memory.statuses ?? null : null;
  memory.watchedAt = Date.now();
  const showing = memory.controller.overlay && app().active && state.page === "terminal" ? state.active : null;
  const looking = memory.keyboard ? showing : null;
  const { statuses, alerts } = agentAlerts(seen, live, looking);
  memory.statuses = statuses;
  const { unseen, dot } = unseenFinishes(memory.unseen, alerts, live, showing);
  memory.unseen = unseen;
  memory.dot = dot;
  memory.marks = `${dot}|${unseen.join(" ")}`;
  if (!alerts.length) return;
  for (const alert of alerts) {
    const tab = state.tabs.find(item => item.address === alert.address);
    // A terminal not yet adopted as a tab (the window hasn't opened since) still has its program's name.
    const name = tabName(tab ?? { title: "An agent" }, live.find(item => item.address === alert.address));
    const { says, level } = ALERTS[alert.kind];
    // The receiver lives as long as its toast, even after the main window is
    // hidden. Commands reach shown mod copies only in Herdr 0.1.11.
    openOverlay({ mod: "float-space", kind: "window", frame: "none", width: 2, height: 2,
      at: { x: 0, y: 0 }, props: { role: "alert", address: alert.address, title: `${name} ${says}`, level } });
  }
  // Herdr's own sounds, or the files settings.json names; off with them.
  if (settings().sounds?.enabled !== false) {
    playSound(alerts.some(alert => alert.kind !== "done") ? "blocked" : "done");
  }
}

// Checks the agents once a second. Unseen finishes live in memory, not in
// Herdr's live data, so a view drawing them (the button's dot, the tabs'
// done dots) redraws itself when the check changes them.
function watchesAgents(view, cx) {
  cx.timer.every(1000, cx => {
    watchAgents();
    if (windowShared().marks !== view.drawnMarks) cx.notify();
  });
}

// A press on the header's own controls puts the keyboard in the window too.
function grab(view) {
  return (_event, cx) => { cx.stop_propagation(); view.headerClicked = true; view.handle?.focus(); showFocus(true); };
}
function focusKey() {
  const now = focused();
  return `${now?.pane}|${now?.terminal}`;
}
// The icon from the app's program table: a one-color glyph or a picture.
function programIcon(program, color) {
  if (!program?.icon) return null;
  return program.tint ? svg(program.icon).size(14).flex_none().text_color(color) : image(program.icon).size(14).flex_none();
}

// A hover label drawn like Herdr's popups (popover fill, 1px border, 6px radius,
// soft shadow) at tooltip size. HoverCard draws no surface of its own.
function hoverLabel(t, text) {
  return div().px(8).py(4).rounded(6).bg(t.popover).border(1).border_color(t.border).shadow_md()
    .text_size(12).text_color(t.foreground).whitespace_nowrap().child(text);
}

// A note's color as a dot; the theme's is a ring around the background.
function colorDot(t, color, size) {
  return div().size(size).flex_none().rounded_full().border_1()
    .border_color(color ? "#00000033" : t.dim).bg(color ? color.background : t.background);
}

// The color Notes and the window's bottom band paint: the shown note's, or
// the theme's.
function notesLook(t, note) {
  const color = noteColor(note);
  return color ? { background: color.background, foreground: color.foreground } : { background: t.background, foreground: t.foreground };
}

export default class FloatSpace extends View {
  init(_props, cx) {
    this.copyProps = props() ?? {};
    // `mod.open` (the shortcut) opens a copy with only an overlay id. A layout
    // block without a role is an optional button.
    const role = this.copyProps.role;
    this.role = role ?? (this.copyProps.overlay ? "run" : "launcher");
    if (this.role === "run") {
      const owner = this.copyProps.overlay;
      cx.spawn(cx => executeCommand(this.copyProps.command ?? "toggle", owner, cx));
    } else if (this.role === "alert") {
      const { overlay, address, title, level } = this.copyProps;
      const command = `alert-${overlay}`;
      // Herdr's agent toast: its title and level, no body (a Float Space
      // terminal has no space or tab) and Herdr's own timeout, which this
      // receiver only mirrors to know when to go.
      const timeout = level === "error" || level === "warning" ? 8000 : 5000;
      this.toast = notify({ title, level, action: { name: `float-space.${command}` } });
      cx.spawn(async cx => {
        for (;;) {
          if (await nextCommand() !== command) continue;
          this.expiry?.cancel();
          // This receiver survives the main window's remount. Finish here:
          // closing immediately after handing work to a new copy can cancel
          // that copy's first hc call in Herdr 0.1.11.
          await executeCommand(`reveal-${address}`, overlay, cx);
          return;
        }
      });
      this.expiry = cx.timer.after(timeout + 250, () => closeOverlay(overlay));
    } else if (this.role === "size") {
      // Lets the size button close this popup instead of opening another.
      globalThis[SIZE_POPUP] = { overlay: this.copyProps.overlay };
      const size = readState(shared(STATE_KEY)).size;
      this.sliders = {};
      for (const key of ["width", "height"]) {
        const slider = SliderState.new({ min: Math.round(MIN_SIZE * 100), max: Math.round(MAX_SIZE * 100), step: 1, value: Math.round(size[key] * 100) });
        slider.on("change", (_value, cx) => cx.notify());
        this.sliders[key] = slider;
      }
    } else if (this.role === "notes-menu") {
      // Lets the Notes tab close this menu instead of opening another.
      globalThis[NOTES_MENU] = { overlay: this.copyProps.overlay };
      this.handle = cx.focus_handle();
      // The row the arrow keys are on; a note being renamed ({id}) or named
      // before it's added ({id: null}); a note waiting for "Delete"; a note
      // whose colors show ({id, cursor} on one of them).
      this.cursor = null;
      this.editing = null;
      this.confirming = null;
      this.coloring = null;
      this.input = InputState.new({ value: "" });
      this.input.on("submit", (_e, cx) => { this.finishEdit(); cx.notify(); });
      followsNotes(cx);
      cx.spawn(async cx => {
        if (notesMemory().doc) await refreshNotes();
        else await ensureNotes(cx);
        const doc = notesMemory().doc;
        if (doc && this.cursor === null) this.cursor = doc.notes.findIndex(note => note.id === doc.active);
        cx.notify();
      });
      cx.timer.after(0, () => this.handle.focus());
    } else if (this.role === "notes") {
      const memory = notesMemory();
      const note = memory.doc ? activeNote(memory.doc) : null;
      // The note this editor holds, and its text as last shown or saved.
      this.noteId = note?.id ?? null;
      this.shownText = note?.text ?? "";
      memory.focus = false;
      this.notes = TextareaState.new({ value: this.shownText, placeholder: "Notes shared across your spaces…" });
      // Auto grow pinned at 10 rows keeps the old size (at least 10 rows,
      // filling the window) but scrolls the way a terminal does. The plain
      // mode, once 24 rows fit, keeps the caret 3 rows above the bottom and
      // clamps only after painting: Enter on the last line drew the text 2
      // rows too high for a frame, then dropped it back. In auto grow the
      // caret may reach the last row and the text never scrolls past its end.
      this.notes.set_auto_grow(10, 10);
      // Save once typing pauses, and when the editor loses the keyboard or
      // closes (switching tabs, hiding, reloading).
      this.notes.on("change", (_e, cx) => {
        this.pendingSave?.cancel();
        this.pendingSave = cx.timer.after(400, () => this.saveNote());
      });
      this.notes.on("focus", () => { windowShared().notesFocused = true; showFocus(true); });
      this.notes.on("blur", () => {
        windowShared().notesFocused = false;
        if (this.pendingSave) this.saveNote();
      });
      followsNotes(cx, cx => this.followNote(cx));
      if (note) {
        cx.timer.after(0, () => this.notes.focus());
        refreshNotes();
      } else {
        // The first opening in this app run reads the file before it shows,
        // and tries again every 2 s while the file can't be read.
        cx.spawn(async cx => {
          while (!(await ensureNotes(cx))) {
            cx.notify();
            await cx.sleep(2000);
          }
          this.followNote(cx);
          cx.notify();
          cx.timer.after(0, () => this.notes.focus());
        });
      }
    } else if (this.role === "bar") {
      this.handle = cx.focus_handle();
      this.headerClicked = false;
      const state = readState(shared(STATE_KEY));
      // Safety guard: hold keyboard in Float Space to prevent keystrokes
      // from leaking to the background pane. Do NOT mark border accent;
      // border stays neutral until the user clicks into the terminal.
      if (state.page !== "notes") cx.timer.after(0, () => this.handle.focus());
      drawsBorder(cx);
      // The Notes tab shows the shown note's name.
      followsNotes(cx);
      cx.spawn(cx => ensureNotes(cx));
      // A failed core query must remain eligible on the next tick. Notes left
      // unsaved by a copy that closed mid-write are saved here too.
      cx.timer.every(3000, () => {
        const memory = windowShared();
        if (!memory.lease && memory.controller.needsReconcile(host())) act("reconcile");
        const notes = notesMemory();
        if (notes.doc && serializeNotes(notes.doc) !== notes.disk) flushNotes();
      });
      // Presses update the border at once; this catches the rest, such as
      // Herdr focusing another pane from the keyboard.
      cx.timer.every(150, () => showFocus(this.keyboard()));
      watchesAgents(this, cx);
      // Only the header consumes navigation commands. Other shown copies
      // receive the same message; executing here prevents duplicate shells.
      cx.spawn(async () => {
        for (;;) {
          const command = await nextCommand();
          if (!["next", "prev", "new", "notes"].includes(command)) continue;
          if (this.copyProps.generation !== windowShared().controller.generation) continue;
          if (globalThis[SIZE_POPUP]?.overlay || globalThis[NOTES_MENU]?.overlay || !this.canNavigate()) continue;
          act(command);
        }
      });
    } else if (this.role === "edge") {
      drawsBorder(cx);
      // The bottom band takes the shown note's color.
      if (this.copyProps.side === "bottom") followsNotes(cx);
    } else if (this.role === "launcher") {
      // The button stays in its layout while the window is hidden, so it
      // keeps the alerts and its dot going then.
      watchesAgents(this, cx);
    }
  }

  canNavigate() {
    return this.handle?.is_focused() || this.keyboard();
  }

  // Whether typing goes into this window: its header, Notes or its terminal.
  // Herdr keeps the pane underneath marked focused in all three cases, and
  // `focused()` doesn't report a terminal in an overlay, so a press inside the
  // window counts until a press elsewhere or Herdr focusing another pane.
  keyboard() {
    if (windowShared().notesFocused) return true;
    if (this.pressedIn && this.pressedIn === focusKey()) return true;
    if (this.headerClicked && this.handle?.is_focused()) return true;
    const now = focused();
    return !now?.pane && readState(shared(STATE_KEY)).tabs.some(tab => tab.address === now?.terminal);
  }

  // Any press outside the header: in the window's body, or anywhere else.
  notePress(event) {
    if (!event.bounds) return;
    const height = readState(shared(STATE_KEY)).size.height * window.viewport_size().height;
    const inside = pressedInWindow(event.position, event.bounds, height);
    this.pressedIn = inside ? focusKey() : null;
    this.headerClicked = false;
    showFocus(inside);
  }

  saveNote() {
    this.pendingSave?.cancel();
    this.pendingSave = null;
    if (!this.noteId) return;
    const text = this.notes.value();
    const id = this.noteId;
    this.shownText = text;
    changeNotes(doc => setNoteText(doc, id, text), true);
  }

  // Shows the note the menu picked, saving what was typed into the one left,
  // or a note's text again after it changed outside Float Space. The editor
  // takes the keyboard only when the menu asked for it.
  followNote(cx) {
    const memory = notesMemory();
    if (!memory.doc) return;
    const note = activeNote(memory.doc);
    if (note.id !== this.noteId) {
      if (this.pendingSave) this.saveNote();
      this.noteId = note.id;
      this.shownText = note.text;
      this.notes.set_value(note.text);
    } else if (!this.pendingSave && note.text !== this.shownText) {
      this.shownText = note.text;
      this.notes.set_value(note.text);
    }
    if (memory.focus) {
      memory.focus = false;
      cx.timer.after(0, () => this.notes.focus());
    }
  }

  async close() {
    if (this.toast) closeOverlay(this.toast);
    if (this.role === "notes") {
      windowShared().notesFocused = false;
      showFocus(false);
      // The write starts here and lands even when this copy is stopped.
      if (this.pendingSave) this.saveNote();
    }
    if (this.role === "size" && globalThis[SIZE_POPUP]?.overlay === this.copyProps.overlay) globalThis[SIZE_POPUP] = { closedAt: Date.now() };
    if (this.role === "notes-menu" && globalThis[NOTES_MENU]?.overlay === this.copyProps.overlay) globalThis[NOTES_MENU] = { closedAt: Date.now() };
    this.notes?.release();
    this.input?.release();
    for (const slider of Object.values(this.sliders ?? {})) slider.release();
    // Last: it may wait for core. Work started from here is cancelled with
    // this copy, so it must not hand over to another copy.
    if (this.role === "bar") {
      if (this.copyProps.generation === windowShared().controller.generation) {
        windowShared().keyboard = false;
        showFocus(false);
      }
      try { await windowShared().controller.windowClosed(host(), this.copyProps.generation); }
      catch (error) { notify({ title: "Float Space", body: String(error?.message ?? error), level: "error" }); }
    }
  }

  // The confirm dialog's buttons, at popup size: a solid primary, a raised secondary.
  button(id, label, action, primary = false) {
    const t = theme();
    return h_flex().id(id).h(26).px(12).items_center().justify_center().flex_none().rounded(6).border_1()
      .border_color(primary ? t.solid : t.input).bg(primary ? t.solid : t.raised)
      .text_color(primary ? t.solid_foreground : t.foreground).cursor_pointer().hover(s => s.opacity(0.88))
      .on_mouse_down("left", stop).on_click(action).child(label);
  }

  iconButton(id, icon, label, action, press) {
    const t = theme();
    return h_flex().id(id).size(22).items_center().justify_center().flex_none().rounded(6).text_color(t.dim)
      .cursor_pointer().hover(s => s.bg(t.hover).text_color(t.foreground))
      .tooltip(label).accessibility_label(label)
      .on_mouse_down("left", (event, cx) => { cx.stop_propagation(); this.headerClicked = true; this.handle?.focus(); showFocus(true); this.pointer = event.position; press?.(); }).on_click(action)
      .child(svg(`mods/float-space/${icon}.svg`).size(14));
  }

  // A tab as Herdr's tab bar draws one, sized for a 30px header.
  tab(id, icon, label, active, action, extra = [], press = null) {
    const t = theme();
    return h_flex().id(id).h(22).px(8).gap(6).flex_none().items_center().rounded(6)
      .border_1().border_color(active ? t.border : t.background).bg(active ? t.raised : t.background)
      .text_color(active ? t.foreground : t.muted).cursor_pointer().hover(s => s.bg(t.hover))
      .on_mouse_down("left", (event, cx) => { grab(this)(event, cx); press?.(event); }).on_click(action)
      .when(Boolean(icon), el => el.child(icon))
      .child(div().max_w(135).truncate().child(label))
      .children(extra);
  }

  // Notes leads the header: the shown note's name, and a chevron that opens
  // the menu of notes. Pressing the tab while Notes shows opens it too.
  notesTab(shown) {
    const t = theme();
    const doc = notesMemory().doc;
    const note = doc ? activeNote(doc) : null;
    const label = note?.name ?? "Notes";
    const color = noteColor(note);
    const press = event => this.pressNotesMenu(event);
    // A colored note shows its color as a small square, unlike the round
    // status dots of terminal tabs.
    const swatch = color ? div().size(8).flex_none().rounded(2).border_1().border_color("#00000033").bg(color.background) : null;
    // A press on the chevron reaches the tab too, which records where the
    // menu opens; the click stays the chevron's.
    const chevron = div().id("float-notes-menu-button").flex_none().text_color(t.dim).hover(s => s.text_color(t.foreground))
      .tooltip(`Switch notes (up to ${MAX_NOTES})`).accessibility_label("Switch notes")
      .on_click((_e, cx) => { cx.stop_propagation(); this.toggleNotesMenu(); })
      .child(svg("mods/float-space/chevron.svg").size(12));
    return this.tab("float-notes-tab", svg("mods/float-space/notes.svg").size(14).flex_none().text_color(shown ? t.foreground : t.muted),
      label, shown, () => shown ? this.toggleNotesMenu() : act("notes"), [swatch, chevron].filter(Boolean), press)
      .tooltip("Notes shared across your spaces · Ctrl+Shift+N");
  }

  // As with the size popup, a press finds out whether the menu was open. The
  // menu opens under the tab, at its left edge.
  pressNotesMenu(event) {
    const popup = globalThis[NOTES_MENU];
    this.notesMenuWasOpen = Boolean(popup?.overlay) || Date.now() - (popup?.closedAt ?? 0) < 250;
    const local = event.local_position;
    this.notesMenuAt = local && event.bounds
      ? { x: Math.max(0, event.position.x - local.x), y: event.position.y - local.y + event.bounds.height + 6 }
      : { x: Math.max(0, event.position.x - 32), y: event.position.y + 16 };
  }

  toggleNotesMenu() {
    const popup = globalThis[NOTES_MENU];
    if (this.notesMenuWasOpen) {
      if (popup?.overlay) closeOverlay(popup.overlay);
      return;
    }
    openOverlay({ mod: "float-space", props: { role: "notes-menu" }, kind: "popup", width: 248, at: this.notesMenuAt ?? "pointer" });
  }

  // A press outside a popup closes it before the click arrives, so remember
  // whether this press found it open; the click then only closes it.
  pressSize() {
    const popup = globalThis[SIZE_POPUP];
    this.sizeWasOpen = Boolean(popup?.overlay) || Date.now() - (popup?.closedAt ?? 0) < 250;
  }

  toggleSize() {
    const popup = globalThis[SIZE_POPUP];
    if (this.sizeWasOpen) {
      if (popup?.overlay) closeOverlay(popup.overlay);
      return;
    }
    const at = this.pointer ? { x: Math.max(0, this.pointer.x - 280), y: this.pointer.y + 16 } : "pointer";
    openOverlay({ mod: "float-space", props: { role: "size" }, kind: "popup", width: 300, at });
  }

  applySize(width, height) {
    act(`resize-${width}-${height}`);
    closeOverlay(this.copyProps.overlay);
  }

  // The menu of notes. Picking or adding a note shows it, with the keyboard
  // in it, and closes the menu; renaming and deleting keep the menu open.
  showNote(update) {
    const memory = notesMemory();
    memory.focus = true;
    changeNotes(update);
    // The editor already showing that note still takes the keyboard.
    notesChanged();
    if (readState(shared(STATE_KEY)).page !== "notes") act("notes");
    closeOverlay(this.copyProps.overlay);
  }

  startEdit(id) {
    const doc = notesMemory().doc;
    if (!doc || (id === null && doc.notes.length >= MAX_NOTES)) return;
    const name = id === null ? nextNoteName(doc.notes) : doc.notes.find(note => note.id === id)?.name;
    if (name === undefined) return;
    this.input.set_value(name);
    this.input.set_selected_range({ start: 0, end: name.length });
    this.editing = { id };
    this.confirming = null;
    this.coloring = null;
    this.input.focus();
  }

  finishEdit() {
    const editing = this.editing;
    if (!editing) return;
    const name = this.input.value();
    this.editing = null;
    if (editing.id === null) {
      this.showNote(doc => doc.notes.length < MAX_NOTES ? addNote(doc, name) : doc);
      return;
    }
    changeNotes(doc => renameNote(doc, editing.id, name));
    this.handle.focus();
  }

  // An empty note goes at once; one with text asks first.
  askDelete(id) {
    const note = notesMemory().doc?.notes.find(item => item.id === id);
    if (!note) return;
    this.editing = null;
    this.coloring = null;
    if (note.text.trim() === "") this.deleteNote(id);
    else this.confirming = id;
  }

  // The colors, in the row: the theme's first, then NOTE_COLORS.
  startColor(id) {
    const note = notesMemory().doc?.notes.find(item => item.id === id);
    if (!note) return;
    this.editing = null;
    this.confirming = null;
    this.coloring = { id, cursor: NOTE_COLORS.indexOf(noteColor(note)) + 1 };
    this.handle.focus();
  }

  // Keeps the menu open, so the note under it shows the color at once.
  pickColor(id, color) {
    this.coloring = null;
    changeNotes(doc => setNoteColor(doc, id, color));
    this.handle.focus();
  }

  deleteNote(id) {
    this.confirming = null;
    changeNotes(doc => removeNote(doc, id));
    this.handle.focus();
  }

  // ↑/↓ move, Enter picks (or confirms a delete). While a note's colors show,
  // ←/→ move along them and Enter picks one. Esc closes the menu, an
  // unfinished rename with it: Herdr closes a popup on Esc.
  menuKey(event, cx) {
    const doc = notesMemory().doc;
    if (!doc || this.editing) return;
    if (this.confirming) {
      if (event.key !== "enter") return;
      this.deleteNote(this.confirming);
      cx.notify();
      return;
    }
    if (this.coloring) {
      const count = NOTE_COLORS.length + 1;
      if (event.key === "right") this.coloring.cursor = (this.coloring.cursor + 1) % count;
      else if (event.key === "left") this.coloring.cursor = (this.coloring.cursor + count - 1) % count;
      else if (event.key === "enter") this.pickColor(this.coloring.id, NOTE_COLORS[this.coloring.cursor - 1]?.id ?? null);
      else if (event.key === "escape") {
        closeOverlay(this.copyProps.overlay);
        return;
      } else return;
      cx.notify();
      return;
    }
    const rows = doc.notes.length + (doc.notes.length < MAX_NOTES ? 1 : 0);
    if (event.key === "down") this.cursor = this.cursor === null ? 0 : (this.cursor + 1) % rows;
    else if (event.key === "up") this.cursor = this.cursor === null ? rows - 1 : (this.cursor + rows - 1) % rows;
    else if (event.key === "enter" && this.cursor !== null) {
      if (this.cursor < doc.notes.length) this.showNote(current => selectNote(current, doc.notes[this.cursor].id));
      else this.startEdit(null);
    } else if (event.key === "escape") {
      closeOverlay(this.copyProps.overlay);
      return;
    } else return;
    cx.notify();
  }

  // A row's icon button: dim, the foreground under the pointer.
  rowButton(id, icon, label, action) {
    const t = theme();
    return h_flex().id(id).size(22).flex_none().items_center().justify_center().rounded(6).text_color(t.dim)
      .cursor_pointer().hover(s => s.text_color(t.foreground))
      .tooltip(label).accessibility_label(label)
      .on_click((_e, cx) => { cx.stop_propagation(); action(); cx.notify(); })
      .child(svg(`mods/float-space/${icon}.svg`).size(13));
  }

  // The confirm dialog's buttons, at menu-row size.
  smallButton(id, label, action, primary = false) {
    const t = theme();
    return h_flex().id(id).h(22).px(8).items_center().justify_center().flex_none().rounded(6).border_1()
      .border_color(primary ? t.solid : t.input).bg(primary ? t.solid : t.raised)
      .text_size(12).text_color(primary ? t.solid_foreground : t.foreground).cursor_pointer().hover(s => s.opacity(0.88))
      .on_click((_e, cx) => { cx.stop_propagation(); action(); cx.notify(); }).child(label);
  }

  editRow(id) {
    const t = theme();
    return h_flex().id(id).h(31).px(3).flex_none().items_center()
      .child(Input.new(this.input).flex_1().h(25).px(8).rounded(6).border_1().border_color(t.accent).bg(t.background)
        .text_size(12.8).text_color(t.foreground));
  }

  // A note's colors in place of its row: 20px rings around 14px dots, the
  // note's own ringed in `accent`, the keyboard's in `dim`.
  colorRow(note) {
    const t = theme();
    const current = noteColor(note);
    const options = [null, ...NOTE_COLORS];
    return h_flex().id(`float-note-${note.id}`).h(31).px(7).gap(4).flex_none().items_center().rounded(7).bg(t.selected)
      .children(options.map((color, index) => {
        const label = color ? color.label : "Theme";
        const ring = color === current ? t.accent : index === this.coloring.cursor ? t.dim : t.selected;
        return h_flex().id(`float-note-color-${note.id}-${color?.id ?? "theme"}`).size(20).flex_none().items_center().justify_center()
          .rounded_full().border_2().border_color(ring).cursor_pointer().hover(s => s.border_color(color === current ? t.accent : t.foreground))
          .tooltip(label).accessibility_label(`${label} note`)
          .on_click((_e, cx) => { cx.stop_propagation(); this.pickColor(note.id, color?.id ?? null); cx.notify(); })
          .child(colorDot(t, color, 14));
      }));
  }

  noteRow(note, index, doc) {
    const t = theme();
    if (this.editing?.id === note.id) return this.editRow(`float-note-name-${note.id}`);
    if (this.coloring?.id === note.id) return this.colorRow(note);
    if (this.confirming === note.id) {
      return h_flex().id(`float-note-${note.id}`).h(31).pl(9).pr(4).gap(6).flex_none().items_center().rounded(7).bg(t.selected)
        .child(div().flex_1().min_w(0).truncate().child("Delete this note?"))
        .child(this.smallButton(`float-note-delete-${note.id}`, "Delete", () => this.deleteNote(note.id), true))
        .child(this.smallButton(`float-note-keep-${note.id}`, "Cancel", () => { this.confirming = null; this.handle.focus(); }));
    }
    return h_flex().id(`float-note-${note.id}`).h(31).pl(9).pr(3).gap(9).flex_none().items_center().rounded(7).cursor_pointer()
      .when(index === this.cursor, el => el.bg(t.selected)).hover(s => s.bg(t.hover))
      .on_click(() => this.showNote(current => selectNote(current, note.id)))
      .child(note.id === doc.active ? svg("mods/float-space/check.svg").size(14).flex_none() : div().size(14).flex_none())
      .child(div().flex_1().min_w(0).truncate().child(note.name))
      .child(h_flex().id(`float-note-paint-${note.id}`).size(22).flex_none().items_center().justify_center().rounded(6)
        .cursor_pointer().hover(s => s.bg(t.hover))
        .tooltip("Note color").accessibility_label(`Color of ${note.name}`)
        .on_click((_e, cx) => { cx.stop_propagation(); this.startColor(note.id); cx.notify(); })
        .child(colorDot(t, noteColor(note), 12)))
      .child(this.rowButton(`float-note-rename-${note.id}`, "rename", `Rename ${note.name}`, () => this.startEdit(note.id)))
      .when(doc.notes.length > 1, el => el.child(this.rowButton(`float-note-remove-${note.id}`, "close", `Delete ${note.name}`, () => this.askDelete(note.id))));
  }

  newNoteRow(doc) {
    const t = theme();
    if (this.editing && this.editing.id === null) return this.editRow("float-note-name-new");
    const full = doc.notes.length >= MAX_NOTES;
    return h_flex().id("float-note-new").h(31).px(9).gap(9).flex_none().items_center().rounded(7)
      .text_color(full ? t.dim : t.foreground)
      .when(!full, el => el.cursor_pointer().hover(s => s.bg(t.hover)).when(this.cursor === doc.notes.length, row => row.bg(t.selected))
        .on_click((_e, cx) => { this.startEdit(null); cx.notify(); }))
      .child(svg("mods/float-space/plus.svg").size(14).flex_none())
      .child(div().flex_1().child("New note"))
      .child(div().text_size(11).text_color(t.dim).child(`${doc.notes.length} of ${MAX_NOTES}`));
  }

  // Herdr's menus: popover fill, 5px padding, 31px rows with 7px corners.
  renderNotesMenu() {
    const t = theme();
    const memory = notesMemory();
    const doc = memory.doc;
    const menu = v_flex().id("float-notes-menu").track_focus(this.handle).on_key_down((e, cx) => this.menuKey(e, cx))
      .w_full().min_h(0).p(5).bg(t.popover).text_size(12.8).text_color(t.foreground);
    if (!doc) return menu.child(div().px(9).py(7).text_color(t.dim).child(memory.error?.message ?? "Loading notes…"));
    return menu
      .children(doc.notes.map((note, index) => this.noteRow(note, index, doc)))
      .child(div().h(1).mx(4).my(5).flex_none().bg(t.border))
      .child(this.newNoteRow(doc));
  }

  renderLauncher() {
    const t = theme();
    const memory = windowShared();
    this.drawnMarks = memory.marks;
    const dot = Boolean(memory.dot);
    // A finish you haven't seen: a dot at the icon's top right, where its
    // front window leaves room, in Herdr's yellow (its `working` color) and
    // ringed in the bar's color like Herdr's tile dots.
    const icon = div().relative().size(14).flex_none()
      .child(svg("mods/float-space/float.svg").size(14))
      .when(dot, el => el.child(div().absolute().top(-3).right(-4).size(8).rounded_full()
        .border_1().border_color(t.chrome).bg(t.working)));
    // Continues the status bar beside it: chrome, its top border, a rounded button.
    const button = h_flex().id("float-space-launcher").w(26).h(22).items_center().justify_center().rounded(6).text_color(t.muted)
      .cursor_pointer().hover(s => s.bg(t.hover).text_color(t.foreground))
      .accessibility_label("Toggle Float Space (Ctrl+Shift+Space)")
      .on_mouse_down("left", stop).on_click(() => act("toggle"))
      .child(icon);
    // The label waits 1000 ms like the status bar's other buttons; .tooltip() is fixed at 500.
    return h_flex().size_full().items_center().justify_center().bg(t.chrome).border_t(1).border_color(t.border)
      .child(HoverCard.new("float-space-launcher-hover").anchor("bottom_center").open_delay(1000).trigger(button)
        .content(hoverLabel(t, "Float Space · Ctrl+Shift+Space").mb(6)));
  }

  renderBar() {
    const t = theme();
    const state = readState(shared(STATE_KEY));
    const live = terminals();
    const notes = state.page === "notes";
    const ring = windowShared().keyboard ? t.accent : t.input;
    this.drawnMarks = windowShared().marks;
    const unseen = new Set(windowShared().unseen ?? []);
    // The shell entry as Herdr shows it now, so the person's programs.json applies.
    const shell = live.find(item => item.program?.key === "shell")?.program;
    const tabs = state.tabs.map(tab => {
      const terminal = live.find(item => item.address === tab.address);
      const name = tabName(tab, terminal);
      const status = tabStatus(liveStatus(terminal), unseen.has(tab.address));
      const active = state.page === "terminal" && state.active === tab.address;
      return this.tab(`float-tab-${tab.address}`, programIcon(tabProgram(terminal, shell), t.muted), name, active,
        () => act(`select-${tab.address}`), [
          status === "working" ? svg("mods/float-space/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)
            : status ? div().size(6).flex_none().rounded(3).bg(t[status]) : null,
          active ? div().id(`float-end-${tab.address}`).flex_none().text_color(t.dim).hover(s => s.text_color(t.foreground))
            .tooltip(`Close ${name}`).accessibility_label(`Close ${name}`)
            .on_mouse_down("left", grab(this)).on_click((_e, cx) => { cx.stop_propagation(); act(`end-${tab.address}`); })
            .child(svg("mods/float-space/close.svg").size(12)) : null,
        ].filter(Boolean));
    });
    // Notes can't be closed, so it leads the header where a title would be; the
    // terminal tabs follow. Free strip space drags the window. The outer edge is
    // the top of the window's border; the line under the tabs stays neutral.
    return v_flex().id("float-space-bar").track_focus(this.handle).on_mouse_down_out(event => this.notePress(event))
      .on_mouse_down("left", () => { this.headerClicked = true; this.handle.focus(); showFocus(true); })
      .size_full().bg(t.background).border_t(1).border_l(1).border_r(1).rounded_t(10).border_color(ring)
      .child(h_flex().flex_1().min_h(0).px(6).gap(6).items_center().border_b(1).border_color(t.border)
      .text_color(t.foreground).text_size(12)
      .child(this.notesTab(notes))
      .when(tabs.length > 0, el => el.child(div().w(1).h(14).flex_none().bg(t.border)))
      .child(h_flex().id("float-terminal-tabs").flex_1().h_full().min_w(0).items_center().gap(2).overflow_x_scrollbar().children(tabs))
      .child(this.iconButton("float-new-terminal", "plus", "New terminal · Ctrl+Shift+T", () => act("new")))
      .child(this.iconButton("float-size", "size", "Window size", () => this.toggleSize(), () => this.pressSize()))
      .child(this.iconButton("float-hide", "hide", "Hide · Ctrl+Shift+Space", () => act("hide"))));
  }

  // The window's sides and bottom, in the header's border color.
  renderEdge() {
    const t = theme();
    const ring = windowShared().keyboard ? t.accent : t.input;
    if (this.copyProps.side === "bottom") {
      const doc = notesMemory().doc;
      const notes = doc && readState(shared(STATE_KEY)).page === "notes";
      const fill = notes ? notesLook(t, activeNote(doc)).background : t.background;
      return div().size_full().bg(fill).border_b(1).border_l(1).border_r(1).rounded_b(10).border_color(ring);
    }
    return div().size_full().bg(ring);
  }

  // The terminals' font and size from Herdr's settings, so Notes reads like the
  // terminal tabs beside it, on the note's color when it has one. Nothing
  // shows until the notes file has been read.
  renderNotes() {
    const t = theme();
    const look = settings();
    const memory = notesMemory();
    const ready = Boolean(memory.doc && this.noteId);
    const paper = notesLook(t, ready ? memory.doc.notes.find(note => note.id === this.noteId) : null);
    const surface = v_flex().id("float-notes").size_full().min_h(0).bg(paper.background).text_color(paper.foreground)
      .on_mouse_down("left", stop);
    if (!ready) {
      return surface.when(Boolean(memory.error), el => el.child(v_flex().px(16).py(14).gap(6).text_size(12)
        .child(div().text_color(t.muted).child(memory.error.message))
        .child(div().text_color(t.dim).child(`Fix or move ${notesFile()}. Notes opens once it can read it.`))));
    }
    return surface
      .child(Textarea.new(this.notes).flex_1().min_h(0).w_full().px(16).py(14).bg(paper.background).text_color(paper.foreground)
        .font_family(look.font_family ?? "JetBrains Mono").text_size(look.font_size ?? 14));
  }

  renderSize() {
    const t = theme();
    const { size: current, custom } = readState(shared(STATE_KEY));
    const percent = size => `${Math.round(size.width * 100)} × ${Math.round(size.height * 100)}`;
    // Custom is the last size other than a preset; until there is one it
    // shows a dash and does nothing.
    const choices = [...PRESETS, { id: "custom", label: "Custom", ...(custom ?? {}) }];
    return v_flex().w_full().p(14).gap(10).bg(t.popover).text_color(t.foreground).text_size(12)
      .child(div().font_medium().child("Window size"))
      .child(h_flex().gap(6).children(choices.map(choice => {
        const ready = choice.width !== undefined;
        const on = ready && sameSize(current, choice);
        return v_flex().id(`float-preset-${choice.id}`).flex_1().py(6).items_center().rounded(6).border_1()
          .border_color(on ? t.accent : t.input).bg(on ? t.selected : t.raised)
          .when(ready, el => el.cursor_pointer().hover(s => s.bg(t.hover))
            .on_mouse_down("left", stop).on_click(() => this.applySize(Math.round(choice.width * 100), Math.round(choice.height * 100))))
          .child(div().text_color(ready ? t.foreground : t.dim).child(choice.label))
          .child(div().text_size(11).text_color(t.dim).child(ready ? percent(choice) : "—"));
      })))
      .children([["width", "Width"], ["height", "Height"]].map(([key, label]) => {
        const slider = this.sliders[key];
        return v_flex().gap(3)
          .child(h_flex().justify_between().child(label)
            .child(div().text_color(t.muted).child(`${Math.round(slider.value())}%`)))
          .child(Slider.new(slider).accessibility_label(label).w_full().child(
            SliderTrack.new(slider).flex().items_center().h(24).w_full().child(
              // The shell places the thumb's left edge only; center it on the groove.
              SliderIndicator.new(slider).relative().w_full().h(4).rounded(2).bg(t.border)
                .range_style(fill => fill.rounded(2).bg(t.accent))
                .child(SliderThumb.new(slider).size(12).rounded(6).bg(t.foreground).ml(-6).mt(-4)))));
      }))
      .child(h_flex().gap(8).justify_between()
        .child(this.button("float-reset-size", "Reset", (_e, cx) => {
          for (const [key, slider] of Object.entries(this.sliders)) slider.set_value(Math.round(DEFAULT_SIZE[key] * 100));
          cx.notify();
        }))
        .child(this.button("float-apply-size", "Apply", () =>
          this.applySize(...["width", "height"].map(key => Math.round(this.sliders[key].value()))), true)));
  }

  render() {
    if (this.role === "bar") return this.renderBar();
    if (this.role === "notes") return this.renderNotes();
    if (this.role === "notes-menu") return this.renderNotesMenu();
    if (this.role === "size") return this.renderSize();
    if (this.role === "edge") return this.renderEdge();
    if (this.role === "run" || this.role === "alert") return div();
    return this.renderLauncher();
  }
}
