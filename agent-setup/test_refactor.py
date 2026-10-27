"""Exercise the setup checker and offline marketplace staging without touching profiles."""

import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix=".refactor-test-", dir=ROOT)
        self.addCleanup(self.scratch.cleanup)
        self.output = Path(self.scratch.name)

    def run_helper(self, *args, root=ROOT):
        return subprocess.run([sys.executable, str(root / "refactor.py"), *map(str, args)], capture_output=True, text=True)

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
                        self.assertTrue((plugin / relative).is_dir(), relative)
                        skill_count += len(list((plugin / relative).rglob("SKILL.md")))
                    hooks = manifest.get("hooks", [])
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
            self.assertEqual(plugins, {"agent-skills", "mattpocock-skills", "ponytail", "chrome-devtools-mcp" if harness == "claude" else "mattpocock-extras"})
            before = {p.relative_to(destination): p.read_bytes() for p in destination.rglob("*") if p.is_file()}
            self.assertNotEqual(self.run_helper("--stage", harness, "--output", destination).returncode, 0)
            self.assertEqual(before, {p.relative_to(destination): p.read_bytes() for p in destination.rglob("*") if p.is_file()})

    def test_rejects_source_drift_before_staging(self):
        fixture = self.output / "fixture"
        fixture.mkdir()
        shutil.copyfile(ROOT / "refactor.py", fixture / "refactor.py")
        for folder in ["universal", "claude", "codex"]:
            shutil.copytree(ROOT / folder, fixture / folder)
        shutil.copytree(ROOT / "hermes", fixture / "hermes")
        source = fixture / "universal/plugins/agent-skills/skills/context-engineering/SKILL.md"
        source.write_text(source.read_text() + "\nchanged fixture\n")
        destination = self.output / "staged"
        result = self.run_helper("--stage", "claude", "--output", destination, root=fixture)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Source drift", result.stderr)
        self.assertFalse(destination.exists())

    def test_generated_references_are_current(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)

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
