#!/usr/bin/env bash
set -euo pipefail
installer="$(cd "$(dirname "$0")" && pwd)/install-sync-worktrees.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
fixture=$(cd "$fixture" && pwd)
export HOME="$fixture/profile"
export CALLS="$fixture/calls"
unset SYNC_WORKTREES_NODE
mkdir -p "$fixture/bin" "$fixture/agents" "$HOME"
: > "$CALLS"
cat > "$fixture/bin/fnm" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'fnm' >> "$CALLS"; printf ' <%s>' "$@" >> "$CALLS"; printf '\n' >> "$CALLS"
state="${CALLS%/*}/node-installed"
case "$1" in
  ls) echo '* v22.1.0 default'; if [[ -f "$state" ]]; then echo '* v24.3.0'; fi ;;
  install) [[ "$2" == 24 ]]; touch "$state" ;;
  exec) [[ "$2" == --using=24 && -f "$state" ]] ;;
  *) exit 99 ;;
esac
MOCK
for agent in claude codex; do
  cat > "$fixture/agents/$agent" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
name=${0##*/}
registered="${CALLS%/*}/$name-mcp"
case "$1 $2" in
  'mcp get') [[ "$3" == sync-worktrees && -f "$registered" ]] ;;
  'mcp add') shift 2; printf '%s\n' "$@" > "$registered" ;;
  *) exit 99 ;;
esac
MOCK
done
chmod +x "$fixture/bin/fnm" "$fixture/agents/claude" "$fixture/agents/codex"
run() {
  local path=$1
  shift
  PATH="$path:/usr/bin:/bin" "$BASH" "$installer" "$@"
}
launcher="$HOME/.local/bin/sync-worktrees-mcp"

[[ "$(run "$fixture/agents")" == 'fnm not installed; skipping sync-worktrees' ]]
[[ ! -e "$HOME/.local" && ! -e "$fixture/claude-mcp" ]]

path="$fixture/bin:$fixture/agents"
diff -u <(printf '%s\n' 'changed: sync-worktrees install' 'changed: claude mcp' 'changed: codex mcp') \
  <(run "$path" --check)
[[ ! -e "$HOME/.local" && ! -e "$fixture/node-installed" && ! -e "$fixture/claude-mcp" ]]

diff -u <(printf '%s\n' 'changed: sync-worktrees install' 'changed: claude mcp' 'changed: codex mcp') \
  <(run "$path" 2>/dev/null)
grep -qx 'fnm <install> <24>' "$CALLS"
grep -qx 'fnm <exec> <--using=24> <npm> <install> <-g> <sync-worktrees>' "$CALLS"
[[ -x "$HOME/.local/bin/sync-worktrees" && -x "$launcher" ]]
diff -u <(printf '%s\n' --scope user sync-worktrees -- "$launcher") "$fixture/claude-mcp"
diff -u <(printf '%s\n' sync-worktrees -- "$launcher") "$fixture/codex-mcp"
"$launcher" --flag 'two words'
grep -qx 'fnm <exec> <--using=24> <sync-worktrees-mcp> <--flag> <two words>' "$CALLS"

: > "$CALLS"
[[ -z "$(run "$path")" && -z "$(run "$path" --check)" ]]
if grep -q 'install' "$CALLS"; then echo 'FAIL: a repeat run installed again' >&2; exit 1; fi

export HOME="$fixture/developer"
mkdir -p "$fixture/dev-bin" "$HOME"
printf '#!/bin/sh\n' > "$fixture/dev-bin/sync-worktrees"
printf '#!/bin/sh\n' > "$fixture/dev-bin/sync-worktrees-mcp"
chmod +x "$fixture/dev-bin/sync-worktrees" "$fixture/dev-bin/sync-worktrees-mcp"
rm "$fixture/claude-mcp" "$fixture/codex-mcp"
: > "$CALLS"
[[ "$(run "$fixture/dev-bin:$path" claude)" == 'changed: claude mcp' ]]
[[ ! -s "$CALLS" && ! -e "$HOME/.local" && ! -e "$fixture/codex-mcp" ]]
diff -u <(printf '%s\n' --scope user sync-worktrees -- "$fixture/dev-bin/sync-worktrees-mcp") "$fixture/claude-mcp"

if run "$fixture/dev-bin:$path" hermes 2>/dev/null; then echo 'FAIL: unsupported harness accepted' >&2; exit 1; fi
echo 'PASS: skip without fnm, preview, install on its own Node, launchers, MCP registration, repeatability, existing copy'
