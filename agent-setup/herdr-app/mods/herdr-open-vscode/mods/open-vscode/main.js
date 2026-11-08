// Opens the focused terminal's folder in this computer's VS Code. A folder on
// another machine opens through the Remote - SSH extension, so the window is
// here and the files stay there. Nothing is needed on the other machine.
//
// Run it with `mod.open {name: "open-vscode"}`: from a key, or a button of yours.
import { View, div } from "gpui-kit";
import { v_flex } from "gpui-base";
import { appHome, closeOverlay, exec, focused, hc, props, readTextFile, spaces, theme, window as appWindow } from "herdr";
import { folderUri, protocolUrl, resolveHost } from "./uri.js";

// A single-quoted PowerShell string.
const ps = (s) => `'${s.replaceAll("'", "''")}'`;

async function launch(folder, host) {
  const uri = folderUri(folder, host);
  const url = protocolUrl(folder, host);
  if (appWindow()?.platform === "windows") {
    const script = `if (Get-Command code -ErrorAction SilentlyContinue) { & code --folder-uri ${ps(uri)} } else { Start-Process ${ps(url)} }`;
    const r = await exec("powershell", ["-NoProfile", "-Command", script]);
    if (r.code !== 0) throw new Error(r.stderr.trim() || `VS Code exited with ${r.code}`);
    return;
  }
  const r = await exec("code", ["--folder-uri", uri]).catch(() => null);
  if (r?.code === 0) return;
  const opener = appWindow()?.platform === "macos" ? "open" : "xdg-open";
  const o = await exec(opener, [url]);
  if (o.code !== 0) throw new Error(o.stderr.trim() || `${opener} exited with ${o.code}`);
}

async function hostOf(machine) {
  const raw = await readTextFile(`${appHome()}/mods/open-vscode/hosts.json`).catch(() => null);
  const overrides = raw ? JSON.parse(raw) : {};
  const r = await hc(["machine", "ls", "--json"]);
  const host = resolveHost(machine, JSON.parse(r.stdout).machines ?? [], overrides);
  if (!host) throw new Error(`No ssh host for "${machine}". Add it to mods/open-vscode/hosts.json: {"${machine}": "<Host in your ssh config>"}`);
  return host;
}

export default class OpenVscode extends View {
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
    const f = focused();
    const space = spaces().find((s) => s.id === f?.space) ?? spaces().find((s) => s.active);
    this.folder = f?.cwd || space?.folder || "";
    this.machine = space?.machine ?? null;
    this.error = this.folder ? null : "This space has no folder yet.";
    if (this.error) return;
    cx.spawn(async (cx) => {
      try {
        await launch(this.folder, this.machine ? await hostOf(this.machine) : null);
        closeOverlay(props().overlay);
      } catch (e) {
        this.error = e?.message ?? String(e);
        cx.notify();
      }
    });
  }

  render() {
    const t = theme();
    return v_flex().id("open-vscode").track_focus(this.handle).size_full().p(16).gap(6).justify_center().bg(t.popover).text_size(13)
      .child(div().text_color(this.error ? t.blocked : t.foreground).font_semibold().child(this.error ? "Could not open VS Code" : "Opening in VS Code…"))
      .child(div().text_size(12).text_color(t.muted).child(this.error ?? `${this.machine ? `${this.machine}:` : ""}${this.folder}`));
  }
}
