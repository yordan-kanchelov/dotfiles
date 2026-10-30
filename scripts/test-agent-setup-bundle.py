"""Exercise the setup checker and offline marketplace staging without touching profiles."""

import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


SCRIPTS = Path(__file__).resolve().parent
ROOT = SCRIPTS.parent / "agent-setup"


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix=".agent-setup-bundle-test-", dir=ROOT)
        self.addCleanup(self.scratch.cleanup)
        self.output = Path(self.scratch.name)

    def run_helper(self, *args, script=SCRIPTS / "agent-setup-bundle.py"):
        return subprocess.run([sys.executable, str(script), *map(str, args)], capture_output=True, text=True)

    def test_stages_complete_native_plugins(self):
        for harness, expected in [("claude", 65), ("codex", 67)]:
            destination = self.output / harness
            result = self.run_helper("--stage", harness, "--output", destination)
            self.assertEqual(result.returncode, 0, result.stderr)
            skill_count = 0
            plugins = set()
            for catalog in destination.glob("*/.claude-plugin/marketplace.json"):
                data = json.loads(catalog.read_text())
                for entry in data["plugins"]:
                    plugin = catalog.parent.parent / entry["source"]
                    plugins.add(entry["name"])
                    self.assertTrue((plugin / "LICENSE").is_file())
                    manifests = [plugin / ".codex-plugin/plugin.json", plugin / ".claude-plugin/plugin.json"] if harness == "codex" else [plugin / ".claude-plugin/plugin.json"]
                    manifest = json.loads(next(p for p in manifests if p.exists()).read_text())
                    self.assertEqual(manifest["name"], entry["name"])
                    skills = manifest.get("skills", "./skills/")
                    skills = [skills] if isinstance(skills, str) else skills
                    for relative in skills:
                        self.assertTrue((plugin / relative).is_dir() or "skills" not in manifest, relative)
                        skill_count += len(list((plugin / relative).rglob("SKILL.md")))
                    hooks = manifest.get("hooks", [r for r in ["./hooks/hooks.json"] if (plugin / r).is_file()])
                    hooks = [hooks] if isinstance(hooks, str) else hooks
                    for relative in hooks:
                        hook_file = plugin / relative
                        self.assertTrue(hook_file.is_file(), relative)
                        for module in json.loads(hook_file.read_text()).get("modules", []):
                            self.assertTrue((hook_file.parent / module).is_file(), module)
                    if entry["name"] == "agent-skills":
                        self.assertTrue((plugin / "references/definition-of-done.md").is_file())
                        self.assertTrue((plugin / "agents/code-reviewer.md").is_file())
                        self.assertFalse((plugin / "hooks/hooks.json").exists())
                        self.assertEqual((plugin / ".claude/commands").exists(), harness == "claude")
            self.assertEqual((destination / "skills/unslop/SKILL.md").read_bytes(), (ROOT / "universal/skills/unslop/SKILL.md").read_bytes())
            self.assertEqual(skill_count, expected)
            self.assertEqual(plugins, {"agent-skills", "mattpocock-skills", "ponytail", *(["chrome-devtools-mcp", "image-view"] if harness == "claude" else ["mattpocock-extras"])})
            before = {p.relative_to(destination): p.read_bytes() for p in destination.rglob("*") if p.is_file()}
            self.assertNotEqual(self.run_helper("--stage", harness, "--output", destination).returncode, 0)
            self.assertEqual(before, {p.relative_to(destination): p.read_bytes() for p in destination.rglob("*") if p.is_file()})

    def test_stages_sloptrim_with_detector_and_native_claude_hooks(self):
        for harness in ["claude", "codex", "hermes", "pi"]:
            with self.subTest(harness=harness):
                destination = self.output / harness
                result = self.run_helper("--stage", harness, "--output", destination)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((destination / "skills/unslop/SKILL.md").read_bytes(), (ROOT / "universal/skills/unslop/SKILL.md").read_bytes())
                skill = destination / "skills/sloptrim"
                for relative in ["SKILL.md", "scripts/detect.py", "references/patterns.md", "LICENSE.txt", "NOTICE"]:
                    self.assertEqual((skill / relative).read_bytes(), (ROOT / "universal/skills/sloptrim" / relative).read_bytes())
                manifest = json.loads((skill / ".claude-plugin/plugin.json").read_text())
                for events in manifest["hooks"].values():
                    for event in events:
                        for hook in event["hooks"]:
                            script = hook["command"].split('${CLAUDE_PLUGIN_ROOT}/', 1)[1].rstrip('"')
                            self.assertTrue((skill / script).is_file(), script)
                draft = self.output / "draft.md"
                draft.write_text("The setup copies this file. Run the command again to check it.\n")
                report = subprocess.run([sys.executable, str(skill / "scripts/detect.py"), str(draft)], capture_output=True, text=True)
                self.assertEqual(report.returncode, 0, report.stderr)
                self.assertIsInstance(json.loads(report.stdout)["_metrics"]["ai_tell_score"], (int, float))

    def test_rejects_source_drift_before_staging(self):
        fixture = self.output / "fixture"
        bundle = fixture / "agent-setup"
        bundle.mkdir(parents=True)
        script = fixture / "scripts/agent-setup-bundle.py"
        script.parent.mkdir()
        shutil.copyfile(SCRIPTS / "agent-setup-bundle.py", script)
        for folder in ["universal", "claude", "codex", "hermes"]:
            shutil.copytree(ROOT / folder, bundle / folder)
        source = bundle / "universal/plugins/agent-skills/skills/context-engineering/SKILL.md"
        source.write_text(source.read_text() + "\nchanged fixture\n")
        destination = self.output / "staged"
        result = self.run_helper("--stage", "claude", "--output", destination, script=script)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Source drift", result.stderr)
        self.assertFalse(destination.exists())

    def test_sources_match_manifests(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_inventories_hold_no_home_paths(self):
        for harness in ["claude", "codex", "hermes"]:
            doc = json.loads((ROOT / harness / "inventory.json").read_text())
            if harness != "hermes":
                self.assertEqual(doc["schema_version"], 2, harness)
            self.assertNotIn("/Users/", json.dumps(doc), harness)

    def test_git_preserves_pinned_line_endings(self):
        fixture = self.output / "git-fixture"
        fixture.mkdir()
        subprocess.run(["git", "init", "--quiet", str(fixture)], check=True)
        shutil.copyfile(ROOT / ".gitattributes", fixture / ".gitattributes")
        for relative, content in [("codex/plugins/example/LICENSE", b"license\r\n"), ("universal/skills/unslop/SKILL.md", b"skill\n")]:
            path = fixture / relative
            path.parent.mkdir(parents=True)
            path.write_bytes(content)
            command = ["git", "-C", str(fixture), "-c", "core.autocrlf=true"]
            oid = subprocess.check_output([*command, "hash-object", "-w", "--path", relative, "--stdin"], input=content).strip().decode()
            self.assertEqual(subprocess.check_output([*command, "cat-file", "blob", oid]), content)
            self.assertEqual(subprocess.check_output([*command, "cat-file", "--filters", "--path", relative, oid]), content)

    def test_stages_hermes_without_marketplace_or_startup_hook(self):
        destination = self.output / "hermes"
        result = self.run_helper("--stage", "hermes", "--output", destination)
        self.assertEqual(result.returncode, 0, result.stderr)
        plugin = destination / "plugins/agent-skills"
        manifest = json.loads((plugin / "plugin.json").read_text())
        self.assertIn("$schema", manifest)
        self.assertEqual(len(list((plugin / "skills").rglob("SKILL.md"))), 25)
        self.assertTrue((plugin / "references/security-checklist.md").is_file())
        self.assertFalse((plugin / "hooks").exists())
        self.assertEqual((destination / "skills/unslop/SKILL.md").read_bytes(), (ROOT / "universal/skills/unslop/SKILL.md").read_bytes())


if __name__ == "__main__":
    unittest.main()
