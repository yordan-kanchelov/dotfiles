// The key after the prefix -> [command, args]. Mirrors .config/herdr/config.toml
// on top of the Herdr TUI's defaults.
const picker = ["mod.open", { name: "picker" }];
const openMod = (name) => ["mod.open", { name }];

export const KEYS = {
  w: picker,
  s: picker,
  "shift-s": ["app.settings"],
  "?": ["app.help"],
  "shift-n": ["space.new"],
  "shift-d": ["space.close"],
  "shift-w": ["space.rename"],
  $: ["space.rename"],
  "(": ["space.prev"],
  ")": ["space.next"],
  c: ["tab.new"],
  n: ["tab.next"],
  b: ["tab.prev"],
  "shift-x": ["tab.close"],
  "&": ["tab.close"],
  "shift-t": ["tab.rename"],
  ",": ["tab.rename"],
  v: ["pane.split", { direction: "right" }],
  "%": ["pane.split", { direction: "right" }],
  "-": ["pane.split", { direction: "down" }],
  '"': ["pane.split", { direction: "down" }],
  x: ["pane.close"],
  z: ["pane.zoom"],
  h: ["pane.go", { direction: "left" }],
  j: ["pane.go", { direction: "down" }],
  k: ["pane.go", { direction: "up" }],
  l: ["pane.go", { direction: "right" }],
  "shift-h": ["pane.swap", { direction: "left" }],
  "shift-j": ["pane.swap", { direction: "down" }],
  "shift-k": ["pane.swap", { direction: "up" }],
  "shift-l": ["pane.swap", { direction: "right" }],
  p: ["layout.toggle", { id: "sidebar" }],
  "ctrl-shift-p": openMod("float-space"),
  "ctrl-shift-c": openMod("open-vscode"),
  "ctrl-shift-g": openMod("git-graph"),
};
for (let index = 1; index <= 9; index++) KEYS[index] = ["tab.select", { index }];

// Shifted punctuation arrives as e.g. keystroke "shift-5" with key_char "%".
// Only unmodified or Shift-only keys fall back to key_char, so ctrl-x cancels.
const modified = (keystroke = "") => /(^|-)(ctrl|alt|cmd|super|fn)-/.test(keystroke);
export const commandFor = (event) =>
  KEYS[event.keystroke] ??
  (event.key_char && !modified(event.keystroke) ? KEYS[event.key_char] : undefined);
