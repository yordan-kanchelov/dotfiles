#!/usr/bin/env bash
# Older setups linked these paths into the repository's claude/ and codex/
# bundles, which no longer exist. Replace each such link with a local copy
# restored from Git history so harness configuration survives the upgrade.
set -euo pipefail
check=false
if [[ "${1:-}" == --check ]]; then check=true; fi
repo="$(cd "$(dirname "$0")/.." && pwd)"
physical="$(cd "$repo" && pwd -P)"
for path in .claude/CLAUDE.md .claude/AGENTS.md .claude/settings.json .claude/commands .claude/skills \
  .codex/keybindings.json .codex/AGENTS.md .codex/instructions.md .codex/rules; do
  link="$HOME/$path"
  [[ -L "$link" ]] || continue
  target=$(readlink "$link")
  case "$target" in
    "$repo"/claude/* | "$repo"/codex/*) relative=${target#"$repo"/} ;;
    "$physical"/claude/* | "$physical"/codex/*) relative=${target#"$physical"/} ;;
    *) continue ;;
  esac
  echo "changed: $path becomes a local copy of retired $relative"
  if $check; then continue; fi
  staging=$(mktemp -d "$HOME/.dotfiles-migrate.XXXXXX")
  # At HEAD the path is gone, so the last commit touching it removed it; its parent has the content.
  removal=$(git -C "$repo" rev-list -1 HEAD -- "$relative" 2>/dev/null || true)
  if [[ -n "$removal" ]] && git -C "$repo" cat-file -e "$removal^:$relative" 2>/dev/null; then
    git -C "$repo" archive "$removal^" -- "$relative" | tar -xf - -C "$staging"
  fi
  # Content still at the target (such as ignored synced skills) wins over history.
  if [[ -d "$target" ]]; then
    mkdir -p "$staging/$relative"
    cp -RL "$target/." "$staging/$relative/"
  elif [[ -e "$target" ]]; then
    mkdir -p "$(dirname "$staging/$relative")"
    cp -L "$target" "$staging/$relative"
  fi
  rm "$link"
  if [[ -e "$staging/$relative" ]]; then
    mv "$staging/$relative" "$link"
  else
    echo "warning: $relative is not in Git history; removed the dangling $path link" >&2
  fi
  rm -rf "$staging"
done
