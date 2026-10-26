#!/usr/bin/env bash
set -euo pipefail
source_script="$(cd "$(dirname "$0")" && pwd)/migrate-agent-links.sh"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
fixture=$(cd "$fixture" && pwd)
repo="$fixture/repo"
export HOME="$fixture/profile"
mkdir -p "$repo/scripts" "$repo/claude/skills/tmux" "$repo/codex/rules" "$HOME/.claude" "$HOME/.codex"
cp "$source_script" "$repo/scripts/"
git -C "$repo" init -q
git -C "$repo" config user.email test@example.invalid
git -C "$repo" config user.name test
echo '{"from":"history"}' > "$repo/claude/settings.json"
echo tmux > "$repo/claude/skills/tmux/SKILL.md"
echo 'prefix_rule()' > "$repo/codex/rules/default.rules"
git -C "$repo" add -A
git -C "$repo" commit -qm bundles
git -C "$repo" rm -rq claude codex
git -C "$repo" commit -qm 'retire bundles'
# Ignored skills Claude synced through the old link stay behind in the checkout.
mkdir -p "$repo/claude/skills/synced/docs"
echo synced > "$repo/claude/skills/synced/docs/SKILL.md"
ln -s "$repo/claude/settings.json" "$HOME/.claude/settings.json"
ln -s "$repo/claude/skills" "$HOME/.claude/skills"
ln -s "$repo/codex/rules" "$HOME/.codex/rules"
ln -s "$repo/codex/AGENTS.md" "$HOME/.codex/AGENTS.md"
echo personal > "$fixture/personal.md"
ln -s "$fixture/personal.md" "$HOME/.claude/CLAUDE.md"
migrate="$repo/scripts/migrate-agent-links.sh"

"$BASH" "$migrate" --check > "$fixture/preview"
[[ $(grep -c '^changed:' "$fixture/preview") == 4 ]]
[[ -L "$HOME/.claude/settings.json" && -L "$HOME/.claude/skills" && -L "$HOME/.codex/rules" ]]

"$BASH" "$migrate" > "$fixture/first" 2> "$fixture/warnings"
[[ ! -L "$HOME/.claude/settings.json" && $(cat "$HOME/.claude/settings.json") == '{"from":"history"}' ]]
[[ ! -L "$HOME/.claude/skills" && -f "$HOME/.claude/skills/tmux/SKILL.md" && -f "$HOME/.claude/skills/synced/docs/SKILL.md" ]]
[[ ! -L "$HOME/.codex/rules" && -f "$HOME/.codex/rules/default.rules" ]]
[[ ! -e "$HOME/.codex/AGENTS.md" && ! -L "$HOME/.codex/AGENTS.md" ]]
grep -q 'codex/AGENTS.md is not in Git history' "$fixture/warnings"
[[ -L "$HOME/.claude/CLAUDE.md" ]]
[[ -z $(git -C "$repo" status --porcelain --untracked-files=no) ]]
[[ -z $(find "$HOME" -maxdepth 1 -name '.dotfiles-migrate.*') ]]
[[ -z $("$BASH" "$migrate") ]]
echo 'PASS: retired Claude/Codex links become local copies from history, unrelated links stay, reruns are no-ops'
