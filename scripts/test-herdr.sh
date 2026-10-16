#!/usr/bin/env bash
set -euo pipefail
installer="$(cd "$(dirname "$0")" && pwd)/install-herdr.sh"
fixture=$(mktemp -d)
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
echo '{}' > "$fixture/repo/settings.json"
echo tmux > "$fixture/repo/skills/tmux/SKILL.md"
ln -s "$fixture/repo/settings.json" "$HOME/.claude/settings.json"
ln -s "$fixture/repo/skills" "$HOME/.claude/skills"
bash "$installer" --check claude codex > "$fixture/preview"
[[ -L "$HOME/.claude/skills" && ! -e "$HOME/.codex" ]]
bash "$installer" claude codex > "$fixture/first"
[[ ! -L "$HOME/.claude/skills" && ! -L "$HOME/.claude/settings.json" ]]
[[ "$(cat "$fixture/repo/settings.json")" == '{}' ]]
[[ ! -e "$fixture/repo/skills/herdr" ]]
[[ -f "$HOME/.claude/skills/tmux/SKILL.md" ]]
[[ -f "$HOME/.codex/skills/herdr/SKILL.md" ]]
[[ -z "$(bash "$installer" claude codex)" ]]
SKILL_VERSION=v2 bash "$installer" claude codex > "$fixture/update"
grep -q v2 "$HOME/.codex/skills/herdr/SKILL.md"
echo "PASS: preview, legacy link migration, repository preservation, repeatability and skill update ($fixture)"
