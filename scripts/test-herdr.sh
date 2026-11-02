#!/usr/bin/env bash
set -euo pipefail
installer="$(cd "$(dirname "$0")" && pwd)/install-herdr.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
fixture=$(cd "$fixture" && pwd)
export HOME="$fixture/profile"
unset CLAUDE_CONFIG_DIR CODEX_HOME PI_CODING_AGENT_DIR HERMES_HOME
mkdir -p "$fixture/bin" "$HOME/.claude" "$fixture/repo/skills/tmux"
export PATH="$fixture/bin:$PATH"
cat > "$fixture/bin/herdr" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  --skill) printf '%s\n' '---' 'name: herdr' '---' "${SKILL_VERSION:-v1}" ;;
  'integration status')
    for target in claude codex pi hermes; do
      case "$target" in
        claude) profile="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;
        codex) profile="${CODEX_HOME:-$HOME/.codex}" ;;
        pi) profile="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}" ;;
        hermes) profile="${HERMES_HOME:-$HOME/.hermes}" ;;
      esac
      if [[ -f "$profile/installed" ]]; then
        echo "$target: current (v1)"
      else
        echo "$target: not installed"
      fi
    done ;;
  'integration install claude'|'integration install codex'|'integration install pi'|'integration install hermes')
    target=$3
    case "$target" in
      claude) profile="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;
      codex) profile="${CODEX_HOME:-$HOME/.codex}" ;;
      pi) profile="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}" ;;
      hermes) profile="${HERMES_HOME:-$HOME/.hermes}" ;;
    esac
    mkdir -p "$profile"
    touch "$profile/installed"
    case "$target" in
      claude) echo hook >> "$profile/settings.json" ;;
      hermes) echo hook >> "$profile/config.yaml" ;;
    esac ;;
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
export PI_CODING_AGENT_DIR="$fixture/pi profile"
export HERMES_HOME="$fixture/hermes profile"
export CLAUDE_CONFIG_DIR="$fixture/claude profile"
export CODEX_HOME="$fixture/codex profile"
for target in claude codex pi hermes; do
  printf '#!/bin/sh\nexit 0\n' > "$fixture/bin/$target"
  chmod +x "$fixture/bin/$target"
done
"$BASH" "$installer" --check > "$fixture/four-agent-preview"
[[ ! -e "$PI_CODING_AGENT_DIR" && ! -e "$HERMES_HOME" ]]
[[ ! -e "$CLAUDE_CONFIG_DIR" && ! -e "$CODEX_HOME" ]]
grep -q 'changed: pi skill' "$fixture/four-agent-preview"
grep -q 'changed: hermes integration' "$fixture/four-agent-preview"
mkdir -p "$HERMES_HOME"
echo 'private settings' > "$fixture/repo/hermes-config.yaml"
chmod 600 "$fixture/repo/hermes-config.yaml"
ln -s "$fixture/repo/hermes-config.yaml" "$HERMES_HOME/config.yaml"
"$BASH" "$installer" > "$fixture/four-agent-install"
[[ -f "$PI_CODING_AGENT_DIR/installed" && -f "$HERMES_HOME/installed" ]]
[[ -f "$CLAUDE_CONFIG_DIR/installed" && -f "$CODEX_HOME/installed" ]]
[[ ! -L "$HERMES_HOME/config.yaml" ]]
[[ "$(cat "$fixture/repo/hermes-config.yaml")" == 'private settings' ]]
grep -q hook "$HERMES_HOME/config.yaml"
[[ ! -e "$HOME/.pi" && ! -e "$HOME/.hermes" ]]
[[ -z "$("$BASH" "$installer")" ]]
SKILL_VERSION=v3 "$BASH" "$installer" pi hermes > "$fixture/four-agent-update"
grep -q v3 "$PI_CODING_AGENT_DIR/skills/herdr/SKILL.md"
cmp "$PI_CODING_AGENT_DIR/skills/herdr/SKILL.md" "$HERMES_HOME/skills/herdr/SKILL.md"
HOME="$fixture/default-profile" CLAUDE_CONFIG_DIR='' CODEX_HOME='' PI_CODING_AGENT_DIR='' HERMES_HOME='' \
  "$BASH" "$installer" pi hermes > "$fixture/default-install"
[[ -f "$fixture/default-profile/.pi/agent/skills/herdr/SKILL.md" ]]
[[ -f "$fixture/default-profile/.hermes/installed" ]]
echo "PASS: no-agent and four-agent autodetection, preview, redirected profiles, legacy links, repeatability and skill updates"
