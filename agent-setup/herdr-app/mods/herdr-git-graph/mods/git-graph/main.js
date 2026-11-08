import { View } from "gpui-kit";
import { props } from "herdr";
import { Graph } from "./graph.js";
import { Menu } from "./menu.js";
import { Dialog } from "./dialog.js";
import { Update } from "./update.js";

// One mod, three roles: the graph (a panel or a pane), and over the window the
// right-click menu, the dialogs its actions ask first, and the update window
// (props.role).
export default class GitGraph extends View {
  init(_props, cx) {
    const role = props()?.role;
    this.part = role === "menu" ? new Menu() : role === "dialog" ? new Dialog() : role === "update" ? new Update() : new Graph();
    this.part.init(cx);
  }

  render(cx) { return this.part.render(cx); }
}
