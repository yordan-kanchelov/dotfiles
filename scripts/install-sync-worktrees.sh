#!/usr/bin/env bash
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
server=$(command -v sync-worktrees-mcp || echo "$bin/sync-worktrees-mcp")
for target in ${targets[@]+"${targets[@]}"}; do
  case "$target" in
    claude) add=(claude mcp add --scope user sync-worktrees -- "$server") ;;
    codex) add=(codex mcp add sync-worktrees -- "$server") ;;
    *) echo "Unsupported harness for the sync-worktrees MCP server: $target" >&2; exit 1 ;;
  esac
  if ! "$target" mcp get sync-worktrees >/dev/null 2>&1; then
    echo "changed: $target mcp"
    if ! $check; then "${add[@]}" >&2; fi
  fi
done
