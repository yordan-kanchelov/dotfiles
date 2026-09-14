#!/usr/bin/env python3
"""Required real Ansible execution against fixture HOME, never a live apply."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[1]
ANSIBLE = shutil.which('ansible-playbook')
assert ANSIBLE, 'ansible-playbook is required; skipped is not pass'


def snapshot(root):
    return {str(p.relative_to(root)): ('link', os.readlink(p)) if p.is_symlink()
            else ('file', hashlib.sha256(p.read_bytes()).hexdigest())
            for p in root.rglob('*') if p.is_symlink() or p.is_file()}


with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp)
    control = root / 'control'
    control.mkdir()
    env = {'HOME': str(control), 'PATH': os.environ['PATH'], 'LC_ALL': 'C.UTF-8',
           'ANSIBLE_LOCAL_TEMP': str(control / 'local'), 'ANSIBLE_REMOTE_TEMP': str(control / 'remote'),
           'PYTHONDONTWRITEBYTECODE': '1'}
    vendor = root / 'vendor'
    (vendor / 'default/hypr').mkdir(parents=True)
    (vendor / 'default/hypr/bootstrap.lua').write_text('-- fixture\n')
    command = root / 'omarchy'
    command.write_text('fixture-only')
    baseline_vendor = snapshot(vendor)
    for bash, yazi in [(True, True), (True, False), (False, True), (False, False)]:
        home = root / f'home-{bash}-{yazi}'
        home.mkdir()
        original = (b'# independent fixture, never sourced by Ansible\n'
                    b'[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap\n'
                    b'[[ $- != *i* ]] && return\n'
                    b'source "$OMARCHY_PATH/default/bash/rc"\n'
                    b'# preserve startup exactly\nexport FNM_SENTINEL=unchanged')
        (home / '.bashrc').write_bytes(original)
        untouched = ['.config/starship.toml', '.config/yazi/init.lua', '.config/yazi/theme.toml',
                     '.config/foot/foot.ini', '.config/hypr/hyprland.lua', '.config/hypr/bindings.lua',
                     '.config/omarchy/shell.json', '.config/omarchy/current/theme/colors.toml',
                     '.config/mise/config.toml', '.local/bin/fnm', '.config/fontconfig/fonts.conf',
                     '.zshrc', '.zprofile', '.config/dotfiles/starship.toml']
        for name in untouched:
            path = home / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f'untouched fixture {name}\n')
        before = snapshot(home)
        backup = home / '.dotfiles_backup/run'
        variables = {'home': str(home), 'ansible_distribution': 'Omarchy', 'ansible_os_family': 'Archlinux',
                     'omarchy_path': str(vendor), 'omarchy_command': str(command), 'backup_dir': str(backup),
                     'omarchy_bash_enabled': bash, 'omarchy_yazi_enabled': yazi}
        base = [ANSIBLE, str(REPO / 'setup.yml'), '-i', 'localhost,', '-c', 'local', '-e', json.dumps(variables)]
        for iteration in [0, 1, 2]:
            args = base + ['--tags', 'omarchy_config'] + (['--check', '--diff'] if iteration == 0 else [])
            result = subprocess.run(args, env=env, capture_output=True, text=True)
            assert result.returncode == 0, result.stdout + result.stderr
            if iteration == 0:
                assert snapshot(home) == before
            if iteration == 2 or not bash:
                assert 'changed=0 ' in result.stdout, result.stdout
            print(f'bash={bash} yazi={yazi} iteration={iteration}: ' + result.stdout.split('PLAY RECAP')[1].strip())
        after = snapshot(home)
        for name in untouched:
            assert after[name] == before[name], name
        if bash:
            assert (home / '.bashrc').read_bytes().startswith(original)
            result = subprocess.run(['python3', str(REPO / 'omarchy/config.py'), 'rollback', '--home', str(home),
                                     '--repo', str(REPO), '--backup', str(backup)], env=env, capture_output=True, text=True)
            assert result.returncode == 0, result.stderr
            assert (home / '.bashrc').read_bytes() == original
        else:
            assert snapshot(home) == before
        if bash and yazi:
            for distribution, family, tags in [('Omarchy', 'Archlinux', []), ('Ubuntu', 'Debian', ['--tags', 'omarchy_config'])]:
                variables.update(ansible_distribution=distribution, ansible_os_family=family)
                result = subprocess.run([ANSIBLE, str(REPO / 'setup.yml'), '-i', 'localhost,', '-c', 'local',
                                         '-e', json.dumps(variables)] + tags, env=env, capture_output=True, text=True)
                assert result.returncode == 0 and 'changed=0 ' in result.stdout, result.stdout + result.stderr
    assert snapshot(vendor) == baseline_vendor
print('Omarchy disposable-HOME integration checks passed')
