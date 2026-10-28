"""Check context-tool hooks without running RTK or changing agent profiles."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


HOOK = Path(__file__).resolve().parents[1] / "agent-setup/context-tools/rtk-hook.sh"


class ContextToolTests(unittest.TestCase):
    def test_disabled_hook_does_not_invoke_rtk(self):
        result = subprocess.run(
            ["/bin/sh", str(HOOK), "claude"],
            input="synthetic input",
            text=True,
            capture_output=True,
            env={**os.environ, "RTK_DISABLED": "1", "PATH": "/does-not-exist"},
        )
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, "", ""))

    def test_enabled_hook_preserves_arguments_input_output_and_status(self):
        with tempfile.TemporaryDirectory() as directory:
            scratch = Path(directory)
            fake = scratch / "rtk"
            fake.write_text(
                '#!/bin/sh\n'
                'printf "%s\\n" "$@" > "$RTK_TEST_ARGS"\n'
                'cat > "$RTK_TEST_INPUT"\n'
                'printf "synthetic output"\n'
                'printf "synthetic error" >&2\n'
                'exit 23\n'
            )
            fake.chmod(0o755)
            env = {
                **os.environ,
                "PATH": str(scratch) + os.pathsep + os.environ.get("PATH", ""),
                "RTK_TEST_ARGS": str(scratch / "args"),
                "RTK_TEST_INPUT": str(scratch / "input"),
            }
            for disabled in (None, "0"):
                with self.subTest(RTK_DISABLED=disabled):
                    env.pop("RTK_DISABLED", None)
                    if disabled is not None:
                        env["RTK_DISABLED"] = disabled
                    result = subprocess.run(
                        ["/bin/sh", str(HOOK), "codex", "one argument"],
                        input="synthetic\ninput",
                        text=True,
                        capture_output=True,
                        env=env,
                    )
                    self.assertEqual(result.returncode, 23)
                    self.assertEqual(result.stdout, "synthetic output")
                    self.assertEqual(result.stderr, "synthetic error")
                    self.assertEqual((scratch / "args").read_text(), "hook\ncodex\none argument\n")
                    self.assertEqual((scratch / "input").read_text(), "synthetic\ninput")


if __name__ == "__main__":
    unittest.main()
