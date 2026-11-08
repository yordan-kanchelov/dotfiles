// node --test agent-setup/herdr-app/local-mods/prefix.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";
import { commandFor } from "./prefix/keys.js";

test("plain, shifted, punctuation, digit and modified keys resolve", () => {
  assert.deepEqual(commandFor({ keystroke: "w", key_char: "w" }), ["mod.open", { name: "picker" }]);
  assert.deepEqual(commandFor({ keystroke: "shift-n", key_char: "N" }), ["space.new"]);
  assert.deepEqual(commandFor({ keystroke: "shift-5", key_char: "%" }), ["pane.split", { direction: "right" }]);
  assert.deepEqual(commandFor({ keystroke: "3", key_char: "3" }), ["tab.select", { index: 3 }]);
  assert.deepEqual(commandFor({ keystroke: "ctrl-shift-g" }), ["mod.open", { name: "git-graph" }]);
});

test("unknown keys and escape cancel", () => {
  assert.equal(commandFor({ keystroke: "y", key_char: "y" }), undefined);
  assert.equal(commandFor({ keystroke: "escape" }), undefined);
  assert.equal(commandFor({ keystroke: "ctrl-x", key_char: "x" }), undefined);
  assert.equal(commandFor({ keystroke: "alt-shift-5", key_char: "%" }), undefined);
});
