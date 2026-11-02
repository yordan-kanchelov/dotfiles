"""Check the setup bundle sources or stage a local marketplace."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil


ROOT = Path(__file__).resolve().parent.parent / "agent-setup"


def components():
    return [component for folder in ["universal", "claude", "codex"]
            for component in json.loads((ROOT / folder / "sources.json").read_text())["components"]]


def require(ok, message):
    # Not assert: python -O would strip the integrity checks.
    if not ok:
        raise SystemExit(message)


def check_sources(selected):
    for component in selected:
        name = component["name"]
        artifacts = {a["path"] for a in component["artifacts"]}
        require(component["payload"] in artifacts and set(component["overlays"].values()) <= artifacts, f"Unlisted payload or overlay in {name}")
        require(all(re.fullmatch(r"[a-z0-9][a-z0-9-]*", n) for n in [name, *component["marketplaces"].values()]), f"Invalid name in {name}")
        for artifact in component["artifacts"]:
            path = (ROOT / artifact["path"]).resolve()
            require(path.is_relative_to(ROOT), f"Path outside bundle: {artifact['path']}")
            digest = hashlib.sha256()
            files = sorted(p for p in path.rglob("*") if p.is_file())
            require(all(not p.is_symlink() for p in path.rglob("*")), f"Symlink in {path}")
            for file in files:
                digest.update(file.relative_to(path).as_posix().encode() + b"\0" + hashlib.sha256(file.read_bytes()).digest())
            require(len(files) == artifact["file_count"] and digest.hexdigest() == artifact["tree_sha256"], f"Source drift in {artifact['path']}")
        require(len(list((ROOT / component["payload"]).rglob("SKILL.md"))) == component["skill_count"], f"Skill count mismatch in {name}")


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stage", choices=["claude", "codex", "hermes", "pi"], help="Assemble native plugin payloads and standalone skills without installing")
    parser.add_argument("--output", type=Path, help="New directory for staged marketplaces")
    args = parser.parse_args()
    if bool(args.stage) != bool(args.output):
        parser.error("--stage and --output must be used together")
    selected = components()
    check_sources(selected)
    if args.stage:
        stage(selected, args.stage, args.output)
    else:
        print("Bundled sources agree with their manifests.")


if __name__ == "__main__":
    main()
