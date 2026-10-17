#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export ANSIBLE_LOCAL_TEMP="$fixture/ansible-local"
export ANSIBLE_REMOTE_TEMP="$fixture/ansible-remote"

python3 - <<'PY'
from pathlib import Path
import re
import yaml

for bundle in ('claude', 'codex'):
    assert not any(p.is_file() or p.is_symlink() for p in Path(bundle).rglob('*')), f'Repository bundle remains: {bundle}'

def check(value, path):
    if isinstance(value, dict):
        for key, item in value.items():
            if key in ('src', 'dest', 'path', 'content') and isinstance(item, str):
                assert not re.search(r'(?<![\w.-])\.?(?:claude|codex)[/\\]', item), (path, key, item)
                assert 'BRAVE_API_KEY' not in item, (path, key)
            check(item, path)
    elif isinstance(value, list):
        for item in value:
            check(item, path)

for path in [Path('setup.yml'), Path('windows.yml'), *Path('tasks').glob('*.yml'), *Path('vars').glob('*.yml')]:
    check(yaml.safe_load(path.read_text()), path)
PY

run_links() {
  ansible-playbook setup.yml --tags symlinks \
    -e "home=$fixture/profile" -e "backup_dir=$fixture/backups" > "$fixture/playbook.log" 2>&1 || {
    cat "$fixture/playbook.log"
    return 1
  }
}

mkdir -p "$fixture/profile"
run_links
[[ -L "$fixture/profile/.zshrc" ]]
[[ ! -e "$fixture/profile/.claude" && ! -L "$fixture/profile/.claude" ]]
[[ ! -e "$fixture/profile/.codex" && ! -L "$fixture/profile/.codex" ]]
mkdir -p "$fixture/profile/.claude" "$fixture/profile/.codex"
printf 'existing Claude settings\n' > "$fixture/profile/.claude/settings.json"
printf 'existing Codex config\n' > "$fixture/profile/.codex/config.toml"
cp -R "$fixture/profile/.claude" "$fixture/claude-before"
cp -R "$fixture/profile/.codex" "$fixture/codex-before"
run_links
diff -r "$fixture/claude-before" "$fixture/profile/.claude"
diff -r "$fixture/codex-before" "$fixture/profile/.codex"
grep -Eq 'changed=0[[:space:]]' "$fixture/playbook.log"
echo 'PASS: setup leaves Claude/Codex configuration absent or unchanged'
