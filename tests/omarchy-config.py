#!/usr/bin/env python3
"""Exercise byte-preserving Bash installation without touching user HOME."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('config', REPO / 'omarchy/config.py')
assert SPEC is not None and SPEC.loader is not None and SPEC.origin is not None


class ConfigTests(unittest.TestCase):
    def test_apply_noop_rollback_and_refusal(self):
        assert SPEC is not None and SPEC.loader is not None and SPEC.origin is not None
        self.assertTrue(Path(SPEC.origin).exists(), 'Bash config adapter is missing')
        config = importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(config)
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            original = (b'# user comment\n'
                        b'[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap\n'
                        b'[[ $- != *i* ]] && return\n'
                        b'source "$OMARCHY_PATH/default/bash/rc"\n'
                        b'# existing fnm stays byte identical\nexport USER_CUSTOM=unchanged')
            rc = home / '.bashrc'
            rc.write_bytes(original)
            backup = home / '.dotfiles_backup/test'
            self.assertTrue(config.apply(home, REPO, backup, check=True))
            self.assertEqual(rc.read_bytes(), original)
            self.assertFalse(backup.exists())
            self.assertTrue(config.apply(home, REPO, backup))
            self.assertTrue(rc.read_bytes().startswith(original))
            self.assertFalse(config.apply(home, REPO, backup))
            installed = rc.read_bytes()
            rc.write_bytes(installed + b'# later edit\n')
            with self.assertRaises(ValueError):
                config.rollback(home, REPO, backup)
            rc.write_bytes(installed)
            config.rollback(home, REPO, backup)
            self.assertEqual(rc.read_bytes(), original)
            self.assertFalse((home / '.config/dotfiles/bash/personal.bash').exists())
            for bad in [original + config.BLOCK + config.BLOCK,
                        original + config.BLOCK.replace(b'# END', b'# altered END')]:
                rc.write_bytes(bad)
                with self.assertRaises(ValueError):
                    config.apply(home, REPO, home / '.dotfiles_backup/refused')
                self.assertEqual(rc.read_bytes(), bad)
            rc.write_bytes(b'# unknown layout\n')
            with self.assertRaises(ValueError):
                config.apply(home, REPO, backup)
            rc.write_bytes(original)
            (home / '.config').rename(home / 'config-saved')
            (home / '.config').symlink_to(home / 'config-saved')
            with self.assertRaises(ValueError):
                config.apply(home, REPO, backup)


    def test_sidecar_conflict_backup_and_rollback(self):
        assert SPEC is not None and SPEC.loader is not None
        config = importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(config)
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            original = b'\n'.join(config.PRELUDE) + b'\n# user\n'
            (home / '.bashrc').write_bytes(original)
            dest = home / '.config/dotfiles/bash/personal.bash'
            dest.parent.mkdir(parents=True)
            dest.write_bytes(b'previous sidecar\n')
            backup = home / '.dotfiles_backup/test'
            self.assertTrue(config.apply(home, REPO, backup))
            config.rollback(home, REPO, backup)
            self.assertEqual(dest.read_bytes(), b'previous sidecar\n')
            self.assertFalse(dest.is_symlink())
            self.assertEqual((home / '.bashrc').read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
