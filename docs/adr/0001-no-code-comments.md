# 0001. No code comments; decisions live in ADRs

Status: Accepted, 2026-11-20

## Context

Comments in this repository fell into four groups. Tautologies repeated the code. Stale notes described code that had since changed. Excuses justified a workaround, which then got copied elsewhere. Decision records held rationale that nothing else captured. Only the last group was worth keeping, and inline it went stale silently: when code changed, nothing flagged the comment next to it.

## Decision

- Code carries no comments. Use names, structure and tests to show *what* the code does. Record the *why* in an ADR under `docs/adr/`, or in the commit message when it only explains a single change.
- A workaround gets a GitHub issue, not a comment that excuses it.
- `scripts/check-comments.py` enforces this as a ratchet. `scripts/comment-baseline.json` gives the number of comment lines each file may still hold. CI fails when a file goes over its allowance. It also fails when a file drops below its allowance and the baseline has not been lowered with `--update`, so the count can only go down. `--update` never raises a count.
- Tool directives are not comments and remain: shebangs, `# shellcheck`, `# noqa`, `#Requires`, editor modelines, type-checker pragmas, and Lua `---@`/`--- @sync` annotations (Yazi reads `--- @sync entry`).
- The scan covers tracked files the repository owns. It leaves out the pinned upstream payloads listed in `agent-setup/*/sources.json`, because their bytes are hash-verified and must stay unchanged. It also leaves out vendored Ghostty themes, license files and lock files. `files/secrets.template` is excluded as well, because its `#` lines are template text the user reads in `~/.secrets`, not code comments.
- The `delete-comment` skill (`.claude/skills/delete-comment/`) repeats the triage: list, classify, record, file, strip, ratchet.

## Consequences

Rationale is now kept away from the code it explains. When you change a file, check the ADR that covers its area (the index is `docs/adr/README.md`) and update it in the same change. ADRs are cheap to amend: edit the bullet, and if the decision is reversed, mark it superseded instead of deleting it.
