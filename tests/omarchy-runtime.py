#!/usr/bin/env python3
"""Required host-library-backed, network-isolated real-manager KEEP matrix.

Run on an Omarchy tooling host with DOTFILES_TEST_FNM and DOTFILES_TEST_NODE24
pointing to genuine executables ONLY. Never copies real runtime configuration.
Missing prerequisites fail; ordinary Ubuntu CI cannot substitute stub managers.
"""
import hashlib
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import subprocess
import struct
import tempfile
import termios
import time

REPO = Path(__file__).resolve().parents[1]
FNM = Path(os.environ['DOTFILES_TEST_FNM']).resolve()
NODE24 = Path(os.environ['DOTFILES_TEST_NODE24']).resolve()
assert all(p.is_file() for p in [FNM, NODE24, Path('/usr/bin/node'), Path('/usr/bin/mise'),
                                Path('/usr/share/omarchy/default/bash/rc')])
assert shutil.which('bwrap'), 'Bubblewrap required; no unsandboxed fallback'
spec = importlib.util.spec_from_file_location('config', REPO / 'omarchy/config.py')
assert spec and spec.loader
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


def hashes(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file() and not p.is_symlink()}


class Child:
    def __init__(self, argv):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execv(argv[0], argv)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack('HHHH', 32, 120, 0, 0))
        self.transcript = b''
        self.drain(2)

    def drain(self, duration):
        output = b''
        end = time.monotonic() + duration
        while time.monotonic() < end:
            if select.select([self.fd], [], [], 0.1)[0]:
                try:
                    output += os.read(self.fd, 65536)
                except OSError:
                    break
        self.transcript += output
        return re.sub(rb'\x1b\[[0-?]*[ -/]*[@-~]', b'', output).replace(b'\r', b'')

    def send(self, command):
        os.write(self.fd, command.encode() + b'\n')
        return self.drain(0.8)

    def close(self):
        try:
            os.kill(self.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        os.waitpid(self.pid, 0)
        os.close(self.fd)


results = []
with tempfile.TemporaryDirectory(prefix='dotfiles-runtime-') as temporary:
    root = Path(temporary)
    # A missing PATH entry is different from a non-executable file (status 126).
    without_mise = root / 'without-mise'
    without_mise.mkdir()
    for executable in Path('/usr/bin').iterdir():
        if executable.name != 'mise':
            (without_mise / executable.name).symlink_to(executable)
    for case in ['fnm', 'mise-installed', 'mise-uninstalled', 'mise-unconfigured', 'system', 'mixed']:
        for login in [False, True]:
            observations = []
            for candidate in [False, True]:
                home = root / f'{case}-{login}-{candidate}'
                home.mkdir()
                project = home / 'project'
                (project / 'nested').mkdir(parents=True)
                (project / '.node-version').write_text('26.8.1\n')
                for name in ['.config', '.local/bin', '.cache', '.local/state', '.config/mise']:
                    (home / name).mkdir(parents=True, exist_ok=True)
                (home / '.config/starship.toml').write_text('format = "PRESERVED> "\n')
                for path in ['.config/yazi/init.lua', '.config/foot/foot.ini', '.config/hypr/bindings.lua']:
                    p = home / path
                    p.parent.mkdir(parents=True, exist_ok=True)
                    p.write_text('# untouched runtime fixture\n')
                if case in ['mise-installed', 'mise-uninstalled', 'mixed']:
                    version = '99.99.99' if case == 'mise-uninstalled' else '26.8.1'
                    (home / '.config/mise/config.toml').write_text(f'[tools]\nnode = "{version}"\n')
                    if case != 'mise-uninstalled':
                        path = home / '.local/share/mise/installs/node/26.8.1/bin'
                        path.mkdir(parents=True)
                        shutil.copy2('/usr/bin/node', path / 'node')
                if case not in ['fnm', 'system']:
                    p = home / '.local/bin/mise'
                    p.write_text('#!/bin/bash\n[[ $1 != activate ]] || printf "mise activate\\n" >> "$HOME/init-calls"\nexec /usr/bin/mise "$@"\n')
                    p.chmod(0o755)
                if case in ['fnm', 'mixed']:
                    for version, binary in [('24.20.0', NODE24), ('26.8.1', Path('/usr/bin/node'))]:
                        path = home / f'.local/share/fnm/node-versions/v{version}/installation/bin'
                        path.mkdir(parents=True)
                        shutil.copy2(binary, path / 'node')
                    path = home / '.local/share/fnm/aliases'
                    path.mkdir(parents=True)
                    (path / 'default').symlink_to('../node-versions/v24.20.0/installation')
                    p = home / '.local/bin/fnm'
                    p.write_text('#!/bin/bash\n[[ $1 != env ]] || printf "fnm env\\n" >> "$HOME/init-calls"\nexec /tools/fnm "$@"\n')
                    p.chmod(0o755)
                original = b'\n'.join(config.PRELUDE) + b'\n'
                if case in ['fnm', 'mixed']:
                    original += b'if [[ -x "$HOME/.local/bin/fnm" ]]; then eval "$("$HOME/.local/bin/fnm" env --use-on-cd --shell bash)"; fi\n'
                original += b'export USER_SENTINEL=preserved\n'
                (home / '.bashrc').write_bytes(original)
                (home / '.bash_profile').write_text('source "$HOME/.bashrc"\n')
                protected = hashes(home / '.config')
                before_rc = hashlib.sha256(original).hexdigest()
                if candidate:
                    config.apply(home, REPO, home / '.dotfiles_backup/run')
                    assert (home / '.bashrc').read_bytes() == original + config.BLOCK
                argv = ['/usr/bin/bwrap', '--unshare-all', '--die-with-parent', '--ro-bind', '/usr', '/usr',
                        '--symlink', 'usr/bin', '/bin', '--symlink', 'usr/lib', '/lib', '--symlink', 'usr/lib', '/lib64',
                        '--proc', '/proc', '--dev', '/dev', '--tmpfs', '/tmp', '--dir', '/etc', '--dir', '/run',
                        '--bind', str(home), '/home/test', '--ro-bind', str(REPO / 'omarchy'), str(REPO / 'omarchy'),
                        '--ro-bind', str(FNM), '/tools/fnm', '--clearenv', '--setenv', 'HOME', '/home/test',
                        '--setenv', 'USER', 'test', '--setenv', 'SHELL', '/bin/bash', '--setenv', 'PATH', '/instrument:/usr/bin',
                        '--setenv', 'TERM', 'xterm-256color', '--setenv', 'LC_ALL', 'C.UTF-8',
                        '--setenv', 'XDG_RUNTIME_DIR', '/tmp/runtime', '--setenv', 'MISE_OFFLINE', '1',
                        '--chdir', '/home/test']
                if case in ['fnm', 'system']:
                    # Missing-manager fixture only; product never changes runtime visibility.
                    argv[argv.index('PATH') + 1] = '/tools/without-mise'
                    argv += ['--ro-bind', str(without_mise), '/tools/without-mise']
                else:
                    # env-bootstrap appends ~/.local/bin, so put the forwarding
                    # observer first explicitly. It always execs the genuine binary.
                    argv += ['--ro-bind', str(home / '.local/bin/mise'), '/instrument/mise']
                argv += ['/usr/bin/bash', '-il' if login else '-i']
                child = Child(argv)
                values = []
                try:
                    for step, directory in [('startup', None), ('enter', '$HOME/project'), ('nested', '$HOME/project/nested'),
                                            ('leave', '$HOME'), ('resource', None)]:
                        if directory:
                            child.send(f'cd "{directory}"')
                        if step == 'resource' and candidate:
                            child.send('source "$HOME/.config/dotfiles/bash/personal.bash"; source "$HOME/.config/dotfiles/bash/personal.bash"')
                        output = child.send('p=$(command -v node); s=$?; printf "\\n@@PATH=%s STATUS=%s\\n" "$(readlink -f "$p")" "$s"; v=$(node --version 2>/dev/null); s=$?; printf "@@VERSION=%s STATUS=%s\\n" "$v" "$s"; printf "@@USER=%s PROMPT=%s\\n" "$USER_SENTINEL" "${STARSHIP_CONFIG-unset}"')
                        records = re.findall(rb'^@@[^\n]*', output, re.M)
                        assert len(records) == 3, (case, login, candidate, step, output)
                        output = child.send('if command -v mise >/dev/null; then mise where node >/dev/null 2>&1; s=$?; else s=127; fi; printf "\\n@@MISE_STATUS=%s\\n" "$s"; printf "@@HOOKS="; { declare -p PROMPT_COMMAND; declare -f cd; } | sha256sum')
                        extra = re.findall(rb'^@@[^\n]*', output, re.M)
                        assert len(extra) == 2, (case, step, output)
                        records += extra
                        values.append([step, [record.decode() for record in records]])
                    if candidate and case == 'system' and not login:
                        child.send('export FZF_CTRL_T_COMMAND=\'printf "qa-file\\n"\' FZF_CTRL_T_OPTS="--select-1 --exit-0" HISTCONTROL=ignorespace')
                        os.write(child.fd, b'printf "GENUINE_FILE=%s\\n" \x14')
                        child.drain(1)
                        output = child.send('')
                        assert b'\nGENUINE_FILE=qa-file\n' in output, output
                        child.send(' export FZF_CTRL_R_OPTS="--filter=RUNTIME_FZF_HISTORY"; history -c; history -s \'printf "RUNTIME_FZF_HISTORY\\n"\'')
                        os.write(child.fd, b'\x12')
                        child.drain(1)
                        output = child.send('')
                        assert b'\nRUNTIME_FZF_HISTORY\n' in output, output
                        child.send(' export FZF_ALT_C_COMMAND=\'printf "%s\\n" "$HOME/project"\' FZF_ALT_C_OPTS="--select-1 --exit-0"')
                        os.write(child.fd, b'\x1bc')
                        child.drain(1)
                        output = child.send('printf "GENUINE_DIR=%s\\n" "$PWD"')
                        assert b'\nGENUINE_DIR=/home/test/project\n' in output, output
                        print('Genuine fzf in official Bash sandbox: Ctrl-T, Ctrl-R and Alt-C passed')
                    calls = (home / 'init-calls').read_text() if (home / 'init-calls').exists() else ''
                    after = hashes(home / '.config')
                    for name, digest in protected.items():
                        assert after[name] == digest, (case, name)
                    observations.append({'values': values, 'init_calls': calls, 'rc_before': before_rc})
                finally:
                    child.close()
                    output_dir = Path(os.environ.get('DOTFILES_RUNTIME_EVIDENCE', str(root / 'logs')))
                    output_dir.mkdir(parents=True, exist_ok=True)
                    (output_dir / f'{case}-{login}-{candidate}.log').write_bytes(child.transcript)
            assert observations[0] == observations[1], (case, login, observations)
            expected_calls = '' if case in ['fnm', 'system'] else 'mise activate\n'
            if case in ['fnm', 'mixed']:
                expected_calls += 'fnm env\n'
            assert observations[0]['init_calls'] == expected_calls, (case, observations)
            if case in ['fnm', 'system']:
                assert observations[0]['values'][0][1][3] == '@@MISE_STATUS=127', observations
            if case in ['fnm', 'mixed']:
                assert 'v24.20.0' in str(observations[0]['values'][0]), observations
                assert 'v26.8.1' in str(observations[0]['values'][1]), observations
            results.append({'case': case, 'login': login, **observations[1], 'equal': True})
            print(f'Runtime KEEP: {case}, login={login}: baseline == candidate including directory hooks and re-source')
    output_dir = Path(os.environ.get('DOTFILES_RUNTIME_EVIDENCE', str(root / 'logs')))
    (output_dir / 'runtime-results.json').write_text(json.dumps(results, indent=2) + '\n')
print('Real-manager runtime matrix passed; genuine binaries staged offline, not installed')
