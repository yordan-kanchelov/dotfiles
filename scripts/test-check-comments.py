#!/usr/bin/env python3
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "check-comments.py"

FIXTURES = {
    "run.sh": """#!/bin/bash
# shellcheck disable=SC2034
echo "#quoted" '#single' ${#var} $# x#y
echo done # trailing
# full line
cat <<'EOF'
#!/bin/sh
# stub comment
echo "${HOME}"
EOF
""",
    "zsh/.zshrc": """if [[ -n ${HOME}/.zcompdump(#qN.mh+24) ]]; then
  : # trailing
fi
""",
    "play.yml": """---
- name: Task # noqa: risky-file-permissions
  url: "https://example.com/#anchor"
  color: '#ffffff'
  value: 1 # trailing
  # full line
  run: |
    # embedded shell
    echo "#x"
""",
    "tool.py": """#!/usr/bin/env python3
# full line
x = "#not" # trailing
""",
    "tool.ps1": """#Requires -Version 5.1
$a = '#not' # trailing
<#
block
#>
$b = @"
# here-string text
"@
""",
    "init.lua": """--- @sync entry
local s = "--not" -- trailing
---@type string
""",
    "mod.js": """const u = "http://x"; // trailing
// full line
/* block
   more */
""",
    "conf.toml": """key = "#not" # trailing
# full line
""",
    "files/secrets.template": "#!/bin/bash\n# template text\n",
    "agent-setup/pinned/payload.sh": "#!/bin/sh\n# upstream comment\n",
    "agent-setup/x/sources.json": json.dumps(
        {"components": [{"artifacts": [{"path": "pinned"}]}]}
    ),
}

EXPECTED = {
    "run.sh": [4, 5, 8],
    "zsh/.zshrc": [2],
    "play.yml": [5, 6, 8],
    "tool.py": [2, 3],
    "tool.ps1": [2, 3, 4, 5],
    "init.lua": [2],
    "mod.js": [1, 2, 3, 4],
    "conf.toml": [1, 2],
}


class CheckComments(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        (self.root / "scripts").mkdir()
        shutil.copy(SCRIPT, self.root / "scripts" / "check-comments.py")
        for rel, text in FIXTURES.items():
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        subprocess.run(["git", "add", "-A"], cwd=self.root, check=True)

    def tearDown(self):
        shutil.rmtree(self.root)

    def run_check(self, *args):
        return subprocess.run(
            [sys.executable, "scripts/check-comments.py", *args],
            cwd=self.root, capture_output=True, text=True,
        )

    def listed(self):
        found = {}
        for line in self.run_check("--list").stdout.splitlines():
            rel, lineno, _ = line.split(":", 2)
            found.setdefault(rel, []).append(int(lineno))
        return found

    def baseline(self):
        return json.loads((self.root / "scripts" / "comment-baseline.json").read_text())

    def test_detects_comments_and_skips_directives_strings_and_exclusions(self):
        self.assertEqual(self.listed(), EXPECTED)

    def test_ratchet_rejects_growth_and_demands_lowering(self):
        self.assertEqual(self.run_check("--init").returncode, 0)
        self.assertEqual(self.run_check().returncode, 0)

        with open(self.root / "conf.toml", "a") as f:
            f.write("# new\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("conf.toml: 3 comment lines, baseline allows 2", result.stdout)
        self.assertEqual(self.run_check("--update").returncode, 1)
        self.assertEqual(self.baseline()["conf.toml"], 2)

        (self.root / "conf.toml").write_text('key = "#not"\n')
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("Ratchet it down", result.stdout)
        self.assertEqual(self.run_check("--update").returncode, 0)
        self.assertNotIn("conf.toml", self.baseline())
        self.assertEqual(self.run_check().returncode, 0)

    def test_new_file_with_comments_fails(self):
        self.run_check("--init")
        (self.root / "new.sh").write_text("#!/bin/sh\n# hello\necho hi\n")
        subprocess.run(["git", "add", "new.sh"], cwd=self.root, check=True)
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertIn("new.sh:2: # hello", result.stdout)

    def test_strip_removes_comments_and_keeps_code(self):
        result = self.run_check("--strip", *EXPECTED)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.listed(), {})
        run = (self.root / "run.sh").read_text()
        self.assertIn('echo "#quoted"', run)
        self.assertIn("echo done\n", run)
        self.assertIn("#!/bin/sh\necho", run)
        self.assertIn("# shellcheck disable=SC2034", run)
        self.assertIn('color: \'#ffffff\'', (self.root / "play.yml").read_text())
        self.assertIn('# here-string text', (self.root / "tool.ps1").read_text())
        self.assertIn("--- @sync entry", (self.root / "init.lua").read_text())
        for rel in ("run.sh", "tool.py"):
            subprocess.run(
                ["bash", "-n", rel] if rel.endswith(".sh") else [sys.executable, "-m", "py_compile", rel],
                cwd=self.root, check=True,
            )


if __name__ == "__main__":
    unittest.main()
