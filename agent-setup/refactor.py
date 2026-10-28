"""Check the setup bundle, regenerate reference tables, or stage a local marketplace."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil


ROOT = Path(__file__).resolve().parent


def counts(doc):
    skills = doc["skills"]
    enabled = {p["id"] for p in doc["plugins"] if p["enabled"]}
    plugin_skills = [s for s in skills if s["kind"] == "plugin"]
    return {
        "installed_plugins": len(doc["plugins"]),
        "enabled_plugins": len(enabled),
        "disabled_plugins": len(doc["plugins"]) - len(enabled),
        "cached_remote_plugins": len(doc["cached_remote_plugins"]),
        "skills_total": len(skills),
        "plugin_skill_files": len(plugin_skills),
        "registered_plugin_candidates": sum(s["registered_candidate"] for s in plugin_skills),
        "enabled_plugin_candidates": sum(s["registered_candidate"] and s["owner"] in enabled for s in plugin_skills),
        "supporting_plugin_files": sum(not s["registered_candidate"] for s in plugin_skills),
        "loose_and_system_skill_files": sum(s["kind"] in {"loose", "system"} for s in skills),
        "synced_skill_files": sum(s["kind"] == "synced" for s in skills),
        "cached_remote_skill_files": sum(s["kind"] == "cached-remote" for s in skills),
        "agent_prompt_files": len(doc["agents"]),
        "hook_declarations": len(doc["hooks"]),
    }


def validate(doc):
    assert doc["schema_version"] == 2
    assert len({s["path"] for s in doc["skills"]}) == len(doc["skills"]), "Duplicate skill paths"
    plugins = doc["plugins"] + doc["cached_remote_plugins"]
    assert len({p["id"] for p in plugins}) == len(plugins), "Duplicate plugin IDs"
    owners = {p["id"]: p for p in plugins}
    for skill in doc["skills"]:
        assert skill["name"] and skill["description"], skill["path"]
        assert re.fullmatch(r"[0-9a-f]{64}", skill["sha256"]), skill["path"]
        assert isinstance(skill["manual_only"], bool)
        if skill["kind"] in {"plugin", "cached-remote"}:
            plugin = owners[skill["owner"]]
            assert skill["path"].startswith(plugin["root"] + "/"), skill["path"]
            contained = any(skill["path"].startswith(root.rstrip("/") + "/") for root in plugin["skill_roots"])
            assert contained == skill["registered_candidate"], skill["path"]
    assert "/Users/" not in json.dumps(doc), "Unsanitized home path"


def table(headers, rows):
    return "\n".join(
        "| " + " | ".join(map(str, row)) + " |"
        for row in [headers, ["---"] * len(headers), *rows]
    )


def plugin_table(doc, cached=False):
    rows = []
    show_revision = not cached and any(p.get("revision") for p in doc["plugins"])
    for plugin in doc["cached_remote_plugins"] if cached else doc["plugins"]:
        skills = [s for s in doc["skills"] if s["owner"] == plugin["id"]]
        row = [f'`{plugin["id"]}`', plugin["version"]]
        if not cached:
            row.append("enabled" if plugin["enabled"] else "disabled")
        row.append(f'{len(skills)} / {sum(s["registered_candidate"] for s in skills)}')
        if show_revision:
            row.append(f'`{plugin["revision"]}`' if plugin.get("revision") else "not recorded for payload")
        rows.append(row)
    headers = ["Plugin", "Version"]
    if not cached:
        headers.append("User state")
    headers.append("Skill files / candidates")
    if show_revision:
        headers.append("Installed revision")
    return table(headers, rows)


def components():
    return [component for folder in ["universal", "claude", "codex"]
            for component in json.loads((ROOT / folder / "sources.json").read_text())["components"]]


def check_sources(selected):
    for component in selected:
        artifacts = {a["path"] for a in component["artifacts"]}
        assert component["payload"] in artifacts and set(component["overlays"].values()) <= artifacts
        assert all(re.fullmatch(r"[a-z0-9][a-z0-9-]*", name) for name in [component["name"], *component["marketplaces"].values()])
        for artifact in component["artifacts"]:
            path = (ROOT / artifact["path"]).resolve()
            assert path.is_relative_to(ROOT), artifact["path"]
            digest = hashlib.sha256()
            files = sorted(p for p in path.rglob("*") if p.is_file())
            assert all(not p.is_symlink() for p in path.rglob("*")), path
            for file in files:
                digest.update(file.relative_to(path).as_posix().encode() + b"\0" + hashlib.sha256(file.read_bytes()).digest())
            assert len(files) == artifact["file_count"] and digest.hexdigest() == artifact["tree_sha256"], f"Source drift in {artifact['path']}"
        assert len(list((ROOT / component["payload"]).rglob("SKILL.md"))) == component["skill_count"], component["name"]


def skill_index(selected):
    lines = ["# Bundled skills", "", "Generated from the payloads and source manifests by `refactor.py`. Manual-only labels describe metadata; shared guidance can impose further limits.", "",
             "Herdr's skill comes from `herdr --skill`. Blender, Unreal, account-managed plugins, and system skills are not bundled.", ""]
    for component in selected:
        lines += [f'## {component["name"]} ({component["skill_count"]})', "",
                  f'Version {component["version"]}. Used by ' + ", ".join(component.get("hosts", component["marketplaces"])) + ".", ""]
        skills = []
        for path in (ROOT / component["payload"]).rglob("SKILL.md"):
            frontmatter = path.read_text().split("---", 2)[1]
            name = re.search(r"^name:\s*(.+)$", frontmatter, re.M)[1].strip("\"'")
            manual = bool(re.search(r"^disable-model-invocation:\s*true\s*$", frontmatter, re.M))
            policy = path.parent / "agents/openai.yaml"
            if policy.exists():
                match = re.search(r"allow_implicit_invocation:\s*(true|false)", policy.read_text())
                if match:
                    manual = match[1] == "false"
            skills.append((name, manual))
        lines += [f"- `{name}`" + (" (manual-only)" if manual else "") for name, manual in sorted(skills)]
        lines.append("")
    return "\n".join(lines)


def stage(selected, harness, output):
    output = output.resolve()
    for component in selected:
        for artifact in component["artifacts"]:
            source = (ROOT / artifact["path"]).resolve()
            if output.is_relative_to(source) or source.is_relative_to(output):
                raise ValueError("Output must be separate from bundled sources")
    output.mkdir(parents=True, exist_ok=False)
    catalogs = {}
    for component in selected:
        if component.get("kind") == "skill":
            if harness in component["hosts"]:
                shutil.copytree(ROOT / component["payload"], output / "skills" / component["name"])
            continue
        marketplace = component["marketplaces"].get(harness)
        hermes_plugin = harness == "hermes" and harness in component.get("hosts", [])
        if not marketplace and not hermes_plugin:
            continue
        target = output / "plugins" / component["name"] if hermes_plugin else output / marketplace / "plugins" / component["name"]
        shutil.copytree(ROOT / component["payload"], target)
        overlay = component["overlays"].get(harness)
        if overlay:
            shutil.copytree(ROOT / overlay, target, dirs_exist_ok=True)
        if hermes_plugin:
            continue
        entry = {"name": component["name"], "source": "./plugins/" + component["name"]}
        if harness == "codex":
            entry.update({"policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}, "category": "Productivity"})
        catalogs.setdefault(marketplace, []).append(entry)
    for marketplace, plugins in catalogs.items():
        manifest = output / marketplace / ".claude-plugin/marketplace.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text(json.dumps({"name": marketplace, "owner": {"name": "Local agent setup"}, "plugins": plugins}, indent=2) + "\n")
    print(f"Staged {harness} marketplaces in {output}. No profile changes made.")


def replace_block(text, name, block):
    pattern = rf"<!-- BEGIN {name} -->\n.*?<!-- END {name} -->"
    assert len(re.findall(pattern, text, re.S)) == 1, f"Missing or duplicate {name} block"
    replacement = f"<!-- BEGIN {name} -->\n{block}\n<!-- END {name} -->"
    return re.sub(pattern, lambda _: replacement, text, flags=re.S)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--write", action="store_true", help="Regenerate inventory counts, tables, and universal/skills.md")
    mode.add_argument("--stage", choices=["claude", "codex", "hermes", "pi"], help="Assemble native plugin payloads and standalone skills without installing")
    parser.add_argument("--output", type=Path, help="New directory for staged marketplaces")
    args = parser.parse_args()
    if bool(args.stage) != bool(args.output):
        parser.error("--stage and --output must be used together")
    selected = components()
    check_sources(selected)
    if args.stage:
        stage(selected, args.stage, args.output)
        return
    docs = [json.loads((ROOT / name / "inventory.json").read_text()) for name in ["claude", "codex"]]
    outputs = {}
    for name, doc in zip(["claude", "codex"], docs):
        validate(doc)
        doc["counts"] = counts(doc)
        outputs[ROOT / name / "inventory.json"] = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
        outputs[ROOT / name / "inventory.md"] = replace_block((ROOT / name / "inventory.md").read_text(), "plugins", plugin_table(doc))
    codex_path = ROOT / "codex/inventory.md"
    outputs[codex_path] = replace_block(outputs[codex_path], "cached-remote", plugin_table(docs[1], cached=True))
    overview = table(["Harness", "CLI", "Installed / enabled / disabled plugins", "Skill files", "Enabled plugin candidates"], [
        [d["harness"], d["cli_version"], f'{d["counts"]["installed_plugins"]} / {d["counts"]["enabled_plugins"]} / {d["counts"]["disabled_plugins"]}', d["counts"]["skills_total"], d["counts"]["enabled_plugin_candidates"]] for d in docs
    ])
    outputs[ROOT / "README.md"] = replace_block((ROOT / "README.md").read_text(), "overview", overview)
    outputs[ROOT / "universal/skills.md"] = skill_index(selected)
    changed = [path for path, text in outputs.items() if path.read_text() != text]
    if args.write:
        for path, text in outputs.items():
            if path in changed:
                path.write_text(text)
        print("Updated " + (", ".join(str(p.relative_to(ROOT)) for p in changed) or "nothing"))
    elif changed:
        parser.exit(1, "Out of date: " + ", ".join(str(p.relative_to(ROOT)) for p in changed) + "\nRun python3 agent-setup/refactor.py --write\n")
    else:
        print("Bundled sources, inventories, counts, generated tables, and skill index agree.")


if __name__ == "__main__":
    main()
