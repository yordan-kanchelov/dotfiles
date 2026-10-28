"""Exercise guarded Headroom patch installation against tiny temporary packages."""

from contextlib import redirect_stdout
import difflib
import hashlib
import importlib.util
import io
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


SOURCE = Path(__file__).with_name("apply-headroom-fixes.py")
spec = importlib.util.spec_from_file_location("headroom_fix_installer", SOURCE)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


@unittest.skipUnless(shutil.which("patch"), "patch utility is required")
class InstallerTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.directory = Path(scratch.name)
        self.root = self.directory / "site-packages/headroom"
        self.root.mkdir(parents=True)
        self.home = self.directory / "home"
        self.home.mkdir()
        self.patch_dir = self.directory / "patches"
        self.patch_dir.mkdir()
        self.originals = {name: f"original {name}\n".encode()
                          for name in ("settings.py", "runtime.py", "dashboard.html")}
        self.changed = {name: value.replace(b"original", b"patched")
                        for name, value in self.originals.items()}
        fixes = {}
        for group, names in (("settings.patch", ("settings.py", "runtime.py")),
                             ("dashboard.patch", ("dashboard.html",))):
            fixes[group] = {}
            diff = []
            for name in names:
                before, after = self.originals[name], self.changed[name]
                (self.root / name).write_bytes(before)
                fixes[group][name] = tuple(hashlib.sha256(data).hexdigest()
                                          for data in (before, after))
                diff.extend(difflib.unified_diff(
                    before.decode().splitlines(keepends=True),
                    after.decode().splitlines(keepends=True),
                    fromfile=f"a/headroom/{name}", tofile=f"b/headroom/{name}"))
            (self.patch_dir / group).write_text("".join(diff))
        overrides = patch.multiple(
            installer, version=lambda _: "0.42.0",
            find_spec=lambda _: SimpleNamespace(origin=str(self.root / "__init__.py")),
            FIXES=fixes, PATCH_DIR=self.patch_dir)
        overrides.start()
        self.addCleanup(overrides.stop)
        home = patch.object(installer.Path, "home", return_value=self.home)
        home.start()
        self.addCleanup(home.stop)

    def apply(self):
        with redirect_stdout(io.StringIO()):
            installer.main()

    def contents(self):
        return {name: (self.root / name).read_bytes() for name in self.originals}

    def backups(self):
        return sorted(path for path in self.home.rglob("*") if path.is_file())

    def test_unknown_version_and_source_make_no_changes(self):
        with patch.object(installer, "version", return_value="0.43.0"):
            with self.assertRaisesRegex(SystemExit, "require Headroom 0.42.0"):
                self.apply()
        self.assertEqual(self.contents(), self.originals)
        (self.root / "dashboard.html").write_bytes(b"unexpected local edit\n")
        before = self.contents()
        with self.assertRaisesRegex(SystemExit, "source differs"):
            self.apply()
        self.assertEqual(self.contents(), before)
        self.assertEqual(self.backups(), [])

    def test_partly_applied_group_is_rejected_before_other_groups_change(self):
        (self.root / "settings.py").write_bytes(self.changed["settings.py"])
        before = self.contents()
        with self.assertRaisesRegex(SystemExit, "source differs"):
            self.apply()
        self.assertEqual(self.contents(), before)
        self.assertEqual(self.backups(), [])

    def test_applied_group_stays_untouched_and_new_group_has_private_backup(self):
        for name in ("settings.py", "runtime.py"):
            (self.root / name).write_bytes(self.changed[name])
        stats = {name: (self.root / name).stat().st_mtime_ns
                 for name in ("settings.py", "runtime.py")}
        self.apply()
        self.assertEqual(self.contents(), self.changed)
        self.assertEqual({name: (self.root / name).stat().st_mtime_ns for name in stats}, stats)
        backups = self.backups()
        self.assertEqual([path.name for path in backups], ["dashboard.html"])
        self.assertEqual(backups[0].read_bytes(), self.originals["dashboard.html"])
        self.assertEqual(stat.S_IMODE(backups[0].stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(backups[0].parent.stat().st_mode), 0o700)
        all_stats = {name: (self.root / name).stat().st_mtime_ns for name in self.originals}
        self.apply()
        self.assertEqual(self.backups(), backups)
        self.assertEqual({name: (self.root / name).stat().st_mtime_ns for name in all_stats}, all_stats)

    def test_later_dry_run_failure_leaves_all_sources_and_backups_untouched(self):
        (self.patch_dir / "dashboard.patch").write_text("not a patch\n")
        with self.assertRaises(subprocess.CalledProcessError):
            self.apply()
        self.assertEqual(self.contents(), self.originals)
        self.assertEqual(self.backups(), [])

    def test_failed_postcheck_restores_pending_files_and_keeps_applied_group(self):
        (self.root / "dashboard.html").write_bytes(self.changed["dashboard.html"])
        dashboard_mtime = (self.root / "dashboard.html").stat().st_mtime_ns
        run = subprocess.run

        def corrupt_after_apply(command, **kwargs):
            result = run(command, **kwargs)
            if "--dry-run" not in command:
                (self.root / "runtime.py").write_bytes(b"corrupted after patch\n")
            return result

        with patch.object(installer.subprocess, "run", side_effect=corrupt_after_apply):
            with self.assertRaisesRegex(RuntimeError, "failed verification"):
                self.apply()
        self.assertEqual(self.contents(), {
            **self.originals, "dashboard.html": self.changed["dashboard.html"]})
        self.assertEqual((self.root / "dashboard.html").stat().st_mtime_ns, dashboard_mtime)
        backups = self.backups()
        self.assertEqual({path.name for path in backups}, {"settings.py", "runtime.py"})
        for saved in backups:
            self.assertEqual(saved.read_bytes(), self.originals[saved.name])
            self.assertEqual(stat.S_IMODE(saved.stat().st_mode), 0o600)


if __name__ == "__main__":
    unittest.main()
