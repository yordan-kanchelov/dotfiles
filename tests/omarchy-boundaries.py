#!/usr/bin/env python3
"""Static ownership and complete legacy disposition inventory gate."""
from pathlib import Path
import re

REPO = Path(__file__).resolve().parents[1]

def text(name):
    return (REPO / name).read_text()

aliases = set(re.findall(r'^alias [\'\"]?([^\s=\'\"]+)[\'\"]?=', text('zsh/.zshrc.core'), re.M))
functions = set(re.findall(r'^([\w]+)\(\)\s*\{', text('zsh/.zshrc.core'), re.M))
ported = {'lg', 'ta', 'tn', 'tls', 'tk', 'tkill', 'tren', 'tnw', 'th', 'tv', 'tkp', 'vim', ':q', 'l', 'ls', 'sw', 'reload', 'y', 'fvim'}
omitted = {'ghcs', 'cleanc', 'cleanp', 'supd', 'c', '_init_fzf', 'clean_dev_caches', 'clean_project', 'cat', 'clear', 'claude'}
assert aliases | functions == ported | omitted, (aliases | functions) ^ (ported | omitted)
assert len(aliases) == 22 and len(functions) == 8
definitions = text('omarchy/shell/aliases.sh') + text('omarchy/bash/personal.bash')
actual = set(re.findall(r'\balias [\'\"]?([^\s=\'\"]+)[\'\"]?=', definitions))
actual |= set(re.findall(r'^\s*([\w]+)\(\)\s*\{', definitions, re.M))
assert actual == ported, actual ^ ported
installer = text('install-omarchy.sh')
assert 'components_csv=bash,yazi' in installer
assert 'optional_csv=shellcheck' in installer
assert 'catalog=(yazi shellcheck git-lfs glow viu)' in installer
for pattern in ['mise where', 'fnm env', 'dev-env node', 'STARSHIP_CONFIG', 'omarchy-zsh']:
    assert pattern not in installer, pattern
for file in ['omarchy/shell/aliases.sh', 'omarchy/bash/personal.bash', 'tasks/omarchy.yml', 'vars/Omarchy.yml']:
    value = text(file)
    for forbidden in ['STARSHIP_CONFIG', '.config/yazi', '.secrets', 'eval ', 'starship init', 'fzf --bash', 'mise where', 'fnm env']:
        assert forbidden not in value, (file, forbidden)
assert not (REPO / 'omarchy/zsh/.zshrc').exists()
assert 'when: omarchy_bash_enabled | bool' in text('tasks/omarchy.yml')
assert 'tags: [omarchy_config, never]' in text('setup.yml')
assert 'when: is_legacy_platform' in text('setup.yml')
assert "when: ansible_os_family == 'Debian' and not is_omarchy" in text('setup.yml')
assert 'not is_omarchy' in text('tasks/desktop.yml')
assert 'omarchy pkg add ansible' in text('bootstrap.sh')
assert 'Prerequisites ready. Next: ./install-omarchy.sh' in text('bootstrap.sh')
print('Omarchy boundaries passed; 22 aliases + 8 functions have explicit dispositions')
