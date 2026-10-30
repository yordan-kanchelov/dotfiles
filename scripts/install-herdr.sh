#!/usr/bin/env bash
# Release-matched skills and integrations for installed dotfiles harnesses.
set -euo pipefail
check=false
if [[ "${1:-}" == --check ]]; then check=true; shift; fi
command -v herdr >/dev/null || { echo 'Herdr not installed; skipping'; exit 0; }
targets=("$@")
if (( ${#targets[@]} == 0 )); then
  for target in claude codex pi hermes; do
    if command -v "$target" >/dev/null; then targets+=("$target"); fi
  done
fi
skill=$(herdr --skill)
status=$(herdr integration status)
# Bash 3.2 (macOS) treats an empty array as unset under nounset.
for target in ${targets[@]+"${targets[@]}"}; do
  case "$target" in
    claude) profile="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" ;;
    codex) profile="${CODEX_HOME:-$HOME/.codex}" ;;
    pi) profile="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}" ;;
    hermes) profile="${HERMES_HOME:-$HOME/.hermes}" ;;
    *) echo "Unsupported dotfiles harness: $target" >&2; exit 1 ;;
  esac
  directory="$profile/skills"
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
      case "$target" in
        claude) config="$profile/settings.json" ;;
        codex) config="$profile/config.toml" ;;
        hermes) config="$profile/config.yaml" ;;
        pi) config="" ;;
      esac
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
