#!/usr/bin/env python3
"""Real controlling PTY: vi edits, completion, history and packaged fzf maps."""
import os
from pathlib import Path
import pty
import re
import select
import shlex
import signal
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
FZF = next((p for p in [Path('/usr/share/fzf/key-bindings.bash'),
                       Path('/usr/share/doc/fzf/examples/key-bindings.bash')] if p.is_file()), None)
assert FZF, 'packaged fzf Bash bindings required; skipped is not pass'


class Shell:
    def __init__(self, home, login=False):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.chdir(home)
            args = ['/bin/bash', '--noprofile', '--norc'] + (['--login'] if login else []) + ['-i']
            os.execve(args[0], args, {'HOME': str(home), 'PATH': '/usr/bin:/bin', 'TERM': 'xterm-256color',
                                    'LC_ALL': 'C', 'INPUTRC': '/dev/null', 'HISTFILE': '/dev/null', 'PS1': 'READY> '})
        self.read()
        self.command('source "$HOME/.bash_profile"')

    def read(self):
        data = b''
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if select.select([self.fd], [], [], 0.2)[0]:
                chunk = os.read(self.fd, 65536)
                data += chunk
                if b'READY> ' in data and not select.select([self.fd], [], [], 0.1)[0]:
                    return re.sub(rb'\x1b\[[0-?]*[ -/]*[@-~]', b'', data).replace(b'\r', b'')
        raise AssertionError(f'PTY timeout: {data!r}')

    def command(self, value):
        os.write(self.fd, value.encode() + b'\n')
        return self.read()

    def close(self):
        try:
            os.kill(self.pid, signal.SIGTERM)
            os.kill(self.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        os.close(self.fd)
        os.waitpid(self.pid, 0)


with tempfile.TemporaryDirectory() as tmp:
    home = Path(tmp)
    for name, source in [('bash/personal.bash', 'omarchy/bash/personal.bash'), ('shell/aliases.sh', 'omarchy/shell/aliases.sh')]:
        dest = home / '.config/dotfiles' / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.symlink_to(REPO / source)
    (home / 'picked dir').mkdir()
    (home / '.bash_profile').write_text('source "$HOME/.bashrc"\n')
    (home / '.bashrc').write_text(f'''[[ $- == *i* ]] || return 0
source {shlex.quote(str(FZF))}
export OMARCHY_PATH={shlex.quote(str(REPO / 'tests/fixtures/omarchy'))}
alias c='opencode --auto'
PROMPT_COMMAND=:
export RUNTIME_SENTINEL=original
export STARSHIP_CONFIG="$HOME/personal-prompt.toml"
before_path=$PATH
before_widgets=$(bind -m vi-insert -X)
source "$HOME/.config/dotfiles/bash/personal.bash"
# Deterministic fzf widget backends: no UI, real history, or external commands.
__fzf_select__() {{ printf '%s' 'PICKED_FILE '; }}
__fzf_history__() {{ READLINE_LINE='printf "FZF_HISTORY_OK\\n"'; READLINE_POINT=${{#READLINE_LINE}}; }}
__fzf_cd__() {{ printf '%s' 'builtin cd -- "$HOME/picked dir"'; }}
''')
    for login in [False, True]:
        shell = Shell(home, login=login)
        try:

            os.write(shell.fd, b'printf "%s\\n" VI_BAD\x1bbcwVI_GOOD\x1b\n')
            out = shell.read()
            assert b'\nVI_GOOD\n' in out, out
            out = shell.command('printf "%s\\n" "$RUNTIME_SENTINEL" "$PROMPT_COMMAND"; test "$PATH" = "$before_path"; test "$(bind -m vi-insert -X)" = "$before_widgets"; printf "STABLE_%s\\n" "$?"')
            assert b'\noriginal\n:\nSTABLE_0\n' in out, out
            out = shell.command('first=$(alias); source "$HOME/.config/dotfiles/bash/personal.bash"; source "$HOME/.config/dotfiles/bash/personal.bash"; test "$(alias)" = "$first"; printf "RESOURCE_%s\\n" "$?"')
            assert b'\nRESOURCE_0\n' in out, out
            out = shell.command('test "$STARSHIP_CONFIG" = "$HOME/personal-prompt.toml"; printf "PROMPT_%s\\n" "$?"')
            assert b'\nPROMPT_0\n' in out, out
            os.write(shell.fd, b'printf "%s\\n" AB\x1b[DC\x1b[CD\n')
            out = shell.read()
            assert b'\nACBD\n' in out, out
            shell.command("complete -W 'alpha bravo' printf")
            # Packaged menu-complete-display-prefix lists first, then selects.
            os.write(shell.fd, b'printf "%s\\n" \x1b[Z')
            first_reverse = shell.read()
            assert b'alpha' in first_reverse and b'bravo' in first_reverse, first_reverse
            os.write(shell.fd, b'\x1b[Z\n')
            out = shell.read()
            assert b'\nbravo\n' in out, out
            # First TAB displays prefix/list, then alpha, bravo, back to alpha.
            os.write(shell.fd, b'printf "%s\\n" \t\t\t\x1b[Z\n')
            out = shell.read()
            assert b'\nalpha\n' in out and b'bravo' in out, out
            shell.command("hcmd() { printf '%s\\n' \"$*\"; }; history -s 'hcmd PREFIX_ONE'; history -s 'hcmd OTHER'; history -s 'hcmd PREFIX_TWO'")
            os.write(shell.fd, b'hcmd PREFIX_\x1b[A\x1b[A\x1b[B\n')
            out = shell.read()
            assert b'\nPREFIX_TWO\n' in out, out
            os.write(shell.fd, b'printf "%s\\n" \x14\n')
            out = shell.read()
            assert b'\nPICKED_FILE\n' in out, out
            os.write(shell.fd, b'\x12\n')
            out = shell.read()
            assert b'\nFZF_HISTORY_OK\n' in out, out
            os.write(shell.fd, b'\x1bc')
            shell.read()
            out = shell.command('printf "CWD=%s\\n" "$PWD"')
            assert f'\nCWD={home}/picked dir\n'.encode() in out, out
            print(f'PTY login={login}: vi change/execute, re-source, TAB/Shift-TAB, prefix Up/Down, fzf Ctrl-T/Ctrl-R/Alt-C passed')
        finally:
            shell.close()
    shell = Shell(home)
    try:
        shell.command('session_local=present; reload --noprofile --norc -i')
        out = shell.command('test -z "${session_local-}"; printf "RELOAD_%s\\n" "$?"')
        assert b'\nRELOAD_0\n' in out, out
        print('PTY reload: exec replacement discarded non-exported shell state')
    finally:
        shell.close()
    for name in ('tkp', ':q'):
        shell = Shell(home)
        os.write(shell.fd, f'{name} 23\n'.encode())
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            pid, status = os.waitpid(shell.pid, os.WNOHANG)
            if pid:
                os.close(shell.fd)
                assert os.waitstatus_to_exitcode(status) == 23
                print(f'PTY {name}: exit status 23')
                break
            time.sleep(0.05)
        else:
            shell.close()
            raise AssertionError(f'{name} did not exit')
print('System/user profiles excluded; fixture startup loaded explicitly in both shell modes')
