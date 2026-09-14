#!/usr/bin/env python3
"""Narrow Bash component transaction. Never import shell or application config."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

BLOCK = b'''\n# BEGIN dotfiles Bash overlay
if [[ $- == *i* && -r "$HOME/.config/dotfiles/bash/personal.bash" ]]; then
  source "$HOME/.config/dotfiles/bash/personal.bash"
fi
# END dotfiles Bash overlay
'''
LINKS = {
    '.config/dotfiles/bash/personal.bash': 'omarchy/bash/personal.bash',
    '.config/dotfiles/shell/aliases.sh': 'omarchy/shell/aliases.sh',
}
PRELUDE = [
    b'[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap',
    b'[[ $- != *i* ]] && return',
    b'source "$OMARCHY_PATH/default/bash/rc"',
]


def safe(path):
    """Reject symlink ancestors rather than following them out of ownership."""
    for parent in [path, *path.parents]:
        if parent.is_symlink():
            raise ValueError(f'symlink boundary refused: {parent}')
        if parent.exists() and not parent.is_dir():
            raise ValueError(f'non-directory ancestor refused: {parent}')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def replace(path, data, mode):
    fd, temporary = tempfile.mkstemp(prefix='.dotfiles-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def layout(data):
    marker = b'dotfiles Bash overlay'
    if marker in data:
        if data.count(marker) != 2 or not data.endswith(BLOCK):
            raise ValueError('duplicate, changed or non-final ownership block refused')
        original = data[:-len(BLOCK)]
    else:
        original = data
    significant = [line for line in original.splitlines() if line.strip() and not line.lstrip().startswith(b'#')]
    if significant[:3] != PRELUDE:
        raise ValueError('unknown Bash loader layout; expected official env, interactive guard, rc in order')
    if original.endswith(b'\\'):
        raise ValueError('unfinished Bash continuation refused')
    result = subprocess.run(['/bin/bash', '--noprofile', '--norc', '-n'], input=original + BLOCK,
                            env={'PATH': '/usr/bin:/bin'}, capture_output=True)
    if result.returncode:
        raise ValueError('Bash syntax check failed (contents not logged)')
    return original


def apply(home, repo, backup, check=False):
    safe(home)
    safe(backup)
    rc = home / '.bashrc'
    if rc.is_symlink() or not rc.is_file() or rc.stat().st_nlink != 1:
        raise ValueError('Bash rc must be an existing regular, unshared file')
    data = rc.read_bytes()
    original = layout(data)
    changes = []
    for dest, source in LINKS.items():
        path = home / dest
        safe(path.parent)
        if not (repo / source).is_file():
            raise ValueError(f'missing repository source: {source}')
        if path.is_symlink() and os.readlink(path) == str(repo / source):
            continue
        if path.exists() and not path.is_file() and not path.is_symlink():
            raise ValueError(f'non-file sidecar refused: {dest}')
        changes.append(dest)
    if data == original + BLOCK and not changes:
        return False
    if check:
        return True
    # Never overwrite an earlier component receipt or backup, even after failure.
    receipt = backup / 'bash-component.json'
    if receipt.exists() or receipt.is_symlink():
        raise ValueError('component backup already exists; use a fresh backup directory')
    saved = backup / 'bash-component'
    if saved.exists() or saved.is_symlink():
        raise ValueError('component backup collision')
    saved.mkdir(parents=True, mode=0o700)
    mode = stat.S_IMODE(rc.stat().st_mode)
    manifest = {'version': 1, 'home': str(home), 'repo': str(repo), 'rc_changed': data != original + BLOCK,
                'before': digest(data), 'after': digest(original + BLOCK), 'mode': mode, 'links': {}}
    if manifest['rc_changed']:
        replace(saved / 'bashrc', data, 0o600)
    for index, dest in enumerate(changes):
        path = home / dest
        exists = path.exists() or path.is_symlink()
        manifest['links'][dest] = {'backup': str(index) if exists else None}
        if exists:
            if path.is_symlink():
                (saved / str(index)).symlink_to(os.readlink(path))
            else:
                shutil.copy2(path, saved / str(index), follow_symlinks=False)
    replace(receipt, json.dumps(manifest, indent=2).encode() + b'\n', 0o600)
    # All refusal checks and backups precede the first config write.
    for dest in changes:
        path = home / dest
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists() or path.is_symlink():
            path.unlink()
        path.symlink_to(repo / LINKS[dest])
    if manifest['rc_changed']:
        replace(rc, original + BLOCK, mode)
    return True


def rollback(home, repo, backup):
    safe(home)
    safe(backup)
    receipt = backup / 'bash-component.json'
    if receipt.is_symlink() or not receipt.is_file():
        raise ValueError('missing regular Bash component receipt')
    record = json.loads(receipt.read_bytes())
    if record['version'] != 1 or record['home'] != str(home) or record['repo'] != str(repo):
        raise ValueError('receipt identity mismatch')
    saved = backup / 'bash-component'
    safe(saved)
    rc = home / '.bashrc'
    if record['rc_changed']:
        if rc.is_symlink() or not rc.is_file() or digest(rc.read_bytes()) != record['after']:
            raise ValueError('Bash rc changed since apply; review and remove only the marked block manually')
        if (saved / 'bashrc').is_symlink() or digest((saved / 'bashrc').read_bytes()) != record['before']:
            raise ValueError('Bash backup changed')
    for dest, entry in record['links'].items():
        if dest not in LINKS or (entry['backup'] is not None and not entry['backup'].isdigit()):
            raise ValueError('invalid component path')
        path = home / dest
        safe(path.parent)
        if not path.is_symlink() or os.readlink(path) != str(repo / LINKS[dest]):
            raise ValueError(f'sidecar changed since apply: {dest}')
        if entry['backup'] is not None and not os.path.lexists(saved / entry['backup']):
            raise ValueError('missing sidecar backup')
    for dest, entry in record['links'].items():
        path = home / dest
        path.unlink()
        if entry['backup'] is not None:
            shutil.copy2(saved / entry['backup'], path, follow_symlinks=False)
    if record['rc_changed']:
        replace(rc, (saved / 'bashrc').read_bytes(), record['mode'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['apply', 'check', 'rollback'])
    parser.add_argument('--home', required=True, type=Path)
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--backup', required=True, type=Path)
    args = parser.parse_args()
    if not all(path.is_absolute() for path in (args.home, args.repo, args.backup)):
        parser.error('paths must be absolute')
    if not args.backup.is_relative_to(args.home / '.dotfiles_backup'):
        parser.error('backup must be under HOME/.dotfiles_backup')
    try:
        if args.action == 'rollback':
            rollback(args.home, args.repo, args.backup)
            changed = True
        else:
            changed = apply(args.home, args.repo, args.backup, check=args.action == 'check')
    except (ValueError, OSError) as error:
        parser.exit(1, f'{error}\n')
    print('changed' if changed else 'unchanged')


if __name__ == '__main__':
    main()
