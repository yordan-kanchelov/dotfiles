#!/usr/bin/env bash
set -euo pipefail
installer="$(cd "$(dirname "$0")" && pwd)/install-herdr.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
fixture=$(cd "$fixture" && pwd)
export HOME="$fixture/profile"
mkdir -p "$fixture/bin" "$HOME/.claude" "$fixture/repo/skills/tmux"
export PATH="$fixture/bin:$PATH"
cat > "$fixture/bin/herdr" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  --skill) printf '%s\n' '---' 'name: herdr' '---' "${SKILL_VERSION:-v1}" ;;
  'integration status')
    for target in claude codex; do
      if [[ -f "$HOME/.$target/installed" ]]; then
        echo "$target: current (v1)"
      else
        echo "$target: not installed"
      fi
    done ;;
  'integration install claude'|'integration install codex')
    target=$3
    mkdir -p "$HOME/.$target"
    touch "$HOME/.$target/installed"
    if [[ "$target" == claude ]]; then echo hook >> "$HOME/.claude/settings.json"; fi ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$fixture/bin/herdr"
# Keep host agent executables out of autodetection, even on developer machines.
mkdir -p "$fixture/no-agent-bin"
cat > "$fixture/no-agent-bin/herdr" <<'MOCK'
#!/bin/bash
case "$*" in
  --skill) echo 'herdr skill' ;;
  'integration status') printf '%s\n' 'claude: not installed' 'codex: not installed' ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$fixture/no-agent-bin/herdr"
for mode in install check; do
  args=()
  if [[ "$mode" == check ]]; then args=(--check); fi
  HOME="$fixture/no-agent-profile" PATH="$fixture/no-agent-bin" \
    "$BASH" "$installer" ${args[@]+"${args[@]}"} > "$fixture/no-agent-$mode"
  [[ ! -s "$fixture/no-agent-$mode" && ! -e "$fixture/no-agent-profile" ]]
done
echo '{}' > "$fixture/repo/settings.json"
echo tmux > "$fixture/repo/skills/tmux/SKILL.md"
ln -s "$fixture/repo/settings.json" "$HOME/.claude/settings.json"
ln -s "$fixture/repo/skills" "$HOME/.claude/skills"
"$BASH" "$installer" --check claude codex > "$fixture/preview"
[[ -L "$HOME/.claude/skills" && ! -e "$HOME/.codex" ]]
"$BASH" "$installer" claude codex > "$fixture/first"
[[ ! -L "$HOME/.claude/skills" && ! -L "$HOME/.claude/settings.json" ]]
[[ "$(cat "$fixture/repo/settings.json")" == '{}' ]]
[[ ! -e "$fixture/repo/skills/herdr" ]]
[[ -f "$HOME/.claude/skills/tmux/SKILL.md" ]]
[[ -f "$HOME/.claude/skills/herdr/SKILL.md" ]]
[[ -f "$HOME/.codex/skills/herdr/SKILL.md" ]]
[[ -f "$HOME/.claude/installed" && -f "$HOME/.codex/installed" ]]
[[ -z "$("$BASH" "$installer" claude codex)" ]]
SKILL_VERSION=v2 "$BASH" "$installer" claude codex > "$fixture/update"
grep -q v2 "$HOME/.codex/skills/herdr/SKILL.md"
echo "PASS: no-agent autodetection, preview, legacy link migration, repository preservation, repeatability and skill update"
