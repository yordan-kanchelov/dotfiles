#!/usr/bin/env python3
"""Only fixture HOME, allowlisted environment and stub command execution."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
ALIASES = REPO / 'omarchy/shell/aliases.sh'


class ShellTests(unittest.TestCase):
    def test_exit_aliases_in_separate_shells(self):
        for name in ('tkp', ':q'):
            with tempfile.TemporaryDirectory() as tmp:
                result = subprocess.run(['/bin/bash', '--noprofile', '--norc'],
                                        input=f'shopt -s expand_aliases\nsource "{ALIASES}"\n{name} 23\nprintf UNREACHABLE\n',
                                        text=True, capture_output=True,
                                        env={'HOME': tmp, 'PATH': tmp, 'LC_ALL': 'C'})
                self.assertEqual(result.returncode, 23, result.stderr)
                self.assertNotIn('UNREACHABLE', result.stdout)

    def test_missing_dependencies_and_noninteractive_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            dependencies = {'lazygit': 'lg', 'eza': 'ls', 'nvim': 'vim', 'yazi': 'y',
                            'fzf': 'fvim', 'bat': 'fvim', 'sync-worktrees': 'sw', 'tmux': 'ta'}
            for missing, symbol in dependencies.items():
                for path in home.iterdir():
                    path.unlink()
                for name in dependencies.keys() - {missing}:
                    path = home / name
                    path.write_text('#!/bin/bash\nexit 99\n')
                    path.chmod(0o755)
                result = subprocess.run(['/bin/bash', '--noprofile', '--norc'],
                                        input=f'source "{ALIASES}"\ntype {symbol} >/dev/null 2>&1 && exit 1\nexit 0\n',
                                        text=True, capture_output=True,
                                        env={'HOME': tmp, 'PATH': tmp, 'LC_ALL': 'C'})
                self.assertEqual(result.returncode, 0, (missing, result.stderr))
            result = subprocess.run(['/bin/bash', '--noprofile', '--norc'],
                                    input=f'source "{REPO}/omarchy/bash/personal.bash"\ndeclare -F\nalias\n',
                                    text=True, capture_output=True,
                                    env={'HOME': tmp, 'PATH': tmp, 'LC_ALL': 'C'})
            self.assertEqual(result.stdout, '')
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_picker_status_paths_cleanup_and_traps(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            binpath = home / 'bin'
            binpath.mkdir()
            for name, body in {
                'yazi': 'for arg; do case $arg in --cwd-file=*) printf "%s" "$PICK" > "${arg#*=}";; esac; done; exit "$STATUS"',
                'fzf': 'printf "%s" "$PICK"; exit "$STATUS"',
                'nvim': 'printf "<%s>" "$@"; exit 7',
                'bat': 'exit 0',
            }.items():
                stub = binpath / name
                stub.write_text('#!/bin/bash\n' + body + '\n')
                stub.chmod(0o755)
            (home / '-dir space').mkdir()
            commands = f'''source '{ALIASES}' || exit
trap ':' EXIT INT TERM
before=$(trap -p)
export PICK='' STATUS=130
y; test $? = 130 || exit 11
fvim; test $? = 130 || exit 12
export STATUS=0
y; test $? = 0 || exit 13
fvim; test $? = 0 || exit 14
export PICK="$PWD"
y; test $? = 0 || exit 19
export PICK='nonexistent-dir'
y 2>/dev/null; test $? != 0 || exit 20
export PICK='-dir space'
y; test $? = 0 || exit 15
test "$PWD" = "$HOME/-dir space" || exit 16
export PICK='-file space'
fvim; test $? = 7 || exit 17
test "$(trap -p)" = "$before" || exit 18
'''
            result = subprocess.run(['/bin/bash', '--noprofile', '--norc'], input=commands,
                                    cwd=tmp, text=True, capture_output=True,
                                    env={'HOME': tmp, 'TMPDIR': tmp, 'PATH': f'{binpath}:/usr/bin:/bin', 'LC_ALL': 'C'})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, '<--><-file space>')
            self.assertEqual(list(home.glob('yazi-cwd.*')), [])

    def test_alias_argv_and_preserved_commands(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            binpath = home / 'bin'
            binpath.mkdir()
            for name in ('tmux', 'nvim', 'eza', 'lazygit', 'sync-worktrees'):
                stub = binpath / name
                stub.write_text('#!/bin/bash\nprintf "<%s>" "$0" "$@"\nprintf "\\n"\n')
                stub.chmod(0o755)
            commands = f'''shopt -s expand_aliases
alias c='opencode --auto'
source '{ALIASES}' || exit
alias c
alias ta tn tls tk tkill tren tnw th tv tkp :q vim l ls lg sw
 ta 'a b'
 tn 'a b'
 tls
 tk 'a b'
 tkill
 tren old 'new name'
 tnw
 th
 tv
 vim -- '-file name'
'''
            result = subprocess.run(['/bin/bash', '--noprofile', '--norc'], input=commands,
                                    text=True, capture_output=True,
                                    env={'HOME': tmp, 'PATH': str(binpath), 'LC_ALL': 'C'})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("alias c='opencode --auto'", result.stdout)
            self.assertIn('<attach-session><-t><a b>', result.stdout)
            self.assertIn('<kill-session><-t><a b>', result.stdout)
            self.assertIn('<kill-server>', result.stdout)
            for argv in ('<new><-s><a b>', '<list-sessions>', '<rename-session><-t><old><new name>',
                         '<new-window>', '<split-window><-h>', '<split-window><-v>'):
                self.assertIn(argv, result.stdout)
            self.assertIn('<--><-file name>', result.stdout)


if __name__ == '__main__':
    unittest.main()
