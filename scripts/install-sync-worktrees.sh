#!/usr/bin/env bash
# sync-worktrees and its MCP server for the installed harnesses.
# The CLI needs Node 24+, newer than the playbook's default Node, so it gets its
# own Node through fnm and two launchers in ~/.local/bin; the default is not
# changed. A copy already on PATH (a dev checkout linked there, say) is left alone.
set -euo pipefail
check=false
if [[ "${1:-}" == --check ]]; then check=true; shift; fi
node_version=${SYNC_WORKTREES_NODE:-24}
bin="$HOME/.local/bin"
export PATH="$bin:$PATH"

if ! command -v sync-worktrees >/dev/null || ! command -v sync-worktrees-mcp >/dev/null; then
  if ! command -v fnm >/dev/null; then
    echo 'fnm not installed; skipping sync-worktrees'
    exit 0
  fi
  echo 'changed: sync-worktrees install'
  if ! $check; then
    # grep without -q: it must drain fnm's output, or pipefail turns fnm's EPIPE
    # into a bogus miss. Installer chatter goes to stderr; stdout carries only
    # the changed: lines.
    if ! fnm ls | grep " v$node_version\." >/dev/null; then fnm install "$node_version" >&2; fi
    fnm exec --using="$node_version" npm install -g sync-worktrees >&2
    mkdir -p "$bin"
    fnm_path=$(command -v fnm)
    for name in sync-worktrees sync-worktrees-mcp; do
      if command -v "$name" >/dev/null; then continue; fi
      printf '%s\n' '#!/bin/sh' \
        "# Written by dotfiles scripts/install-sync-worktrees.sh: runs on Node $node_version whatever the default is." \
        "exec \"$fnm_path\" exec --using=$node_version $name \"\$@\"" > "$bin/$name"
      chmod +x "$bin/$name"
    done
  fi
fi

targets=("$@")
if (( ${#targets[@]} == 0 )); then
  for target in claude codex; do
    if command -v "$target" >/dev/null; then targets+=("$target"); fi
  done
fi
# Absolute path: a client started outside a login shell has neither Homebrew nor
# ~/.local/bin on PATH. The fallback only matters for --check before the install.
server=$(command -v sync-worktrees-mcp || echo "$bin/sync-worktrees-mcp")
# Bash 3.2 (macOS) treats an empty array as unset under nounset.
for target in ${targets[@]+"${targets[@]}"}; do
  case "$target" in
    claude) add=(claude mcp add --scope user sync-worktrees -- "$server") ;;
    codex) add=(codex mcp add sync-worktrees -- "$server") ;;
    *) echo "Unsupported harness for the sync-worktrees MCP server: $target" >&2; exit 1 ;;
  esac
  # Both CLIs exit non-zero from `mcp get` when no server has that name.
  if ! "$target" mcp get sync-worktrees >/dev/null 2>&1; then
    echo "changed: $target mcp"
    if ! $check; then "${add[@]}" >&2; fi
  fi
done
