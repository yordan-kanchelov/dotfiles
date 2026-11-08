// Prefix mode, as in the Herdr TUI: shows a hint and takes the next key. There
// is no timeout, and no key reaches the terminal. Any other key or Esc cancels.

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { closeOverlay, props, run, theme } from "herdr";
import { commandFor } from "./keys.js";

export default class Prefix extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
  }

  render() {
    const t = theme();
    return h_flex()
      .id("prefix")
      .track_focus(this.handle)
      .on_key_down((e, cx) => {
        cx.stop_propagation();
        const command = commandFor(e);
        closeOverlay(props().overlay);
        if (command) run(command[0], command[1] ?? {});
      })
      .size_full()
      .px(12)
      .gap(10)
      .items_center()
      .bg(t.popover)
      .text_size(12)
      .text_color(t.muted)
      .child(div().font_semibold().text_color(t.accent).child("PREFIX"))
      .child("w spaces · c tab · n/b next/prev · v/- split · hjkl panes · ? keys · esc");
  }
}
