#!/usr/bin/env bash
# Release-matched skills and integrations for installed dotfiles harnesses.
set -euo pipefail
check=false
if [[ "${1:-}" == --check ]]; then check=true; shift; fi
command -v herdr >/dev/null || { echo 'Herdr not installed; skipping'; exit 0; }
targets=("$@")
if (( ${#targets[@]} == 0 )); then
  for target in claude codex; do
    if command -v "$target" >/dev/null; then targets+=("$target"); fi
  done
fi
skill=$(herdr --skill)
status=$(herdr integration status)
for target in "${targets[@]}"; do
  case "$target" in claude|codex) ;; *) echo "Unsupported dotfiles harness: $target" >&2; exit 1 ;; esac
  directory="$HOME/.$target/skills"
  if [[ -L "$directory" ]]; then
    echo "changed: $target skills directory"
    if ! $check; then
      temporary=$(mktemp -d)
      cp -RL "$directory/." "$temporary/"
      rm "$directory"
      mv "$temporary" "$directory"
    fi
  fi
  destination="$directory/herdr/SKILL.md"
  if [[ ! -f "$destination" ]] || [[ "$(cat "$destination")" != "$skill" ]]; then
    echo "changed: $target skill"
    if ! $check; then
      mkdir -p "$(dirname "$destination")"
      printf '%s\n' "$skill" > "$destination"
    fi
  fi
  if ! grep -q "^$target: current[ (]" <<< "$status"; then
    echo "changed: $target integration"
    if ! $check; then
      config="$HOME/.codex/config.toml"
      [[ "$target" != claude ]] || config="$HOME/.claude/settings.json"
      if [[ -L "$config" ]]; then
        temporary=$(mktemp)
        cp -L "$config" "$temporary"
        rm "$config"
        cp "$temporary" "$config"
        rm "$temporary"
      fi
      herdr integration install "$target"
    fi
  fi
done
