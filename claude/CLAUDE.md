# CLAUDE.md

Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.
(Simplicity, surgical diffs, root-cause fixes, and comment hygiene are enforced
by the ponytail plugin — not repeated here.)

## Think before coding
State assumptions. If uncertain, ask rather than guess — present the
interpretations when ambiguous. Push back when there's a simpler approach.
Stop when confused and name what's unclear.

## Read before you write
Before adding code, read the exports, immediate callers, and shared utilities.
"Looks orthogonal" is dangerous. If unsure why code is structured a way, ask.

## Goal-driven execution
Define success criteria, then loop until verified. Don't just follow steps —
strong criteria let you iterate independently.

## Surface conflicts, don't average them
If two patterns contradict, pick one (more recent / more tested), say why, and
flag the other for cleanup. Never blend conflicting patterns.

## Match the codebase's conventions, even if you disagree
Conformance > taste inside the codebase. If a convention is genuinely harmful,
surface it — don't fork silently.

## Tests verify intent, not just behavior
Tests encode WHY behavior matters, not only WHAT it does. A test that can't
fail when the business logic changes is wrong.

## Checkpoint and fail loud
Summarize what's done, verified, and left; don't continue from a state you
can't describe back. "Completed" is wrong if anything was skipped silently;
"tests pass" is wrong if any were skipped. Surface uncertainty, don't hide it.

## When writing code that calls an LLM
Use the model for judgment (classification, drafting, summarization,
extraction). Do NOT use it for routing, retries, or deterministic transforms.
If code can answer, code answers.

## The 30-Second Reality Check — must be YES to all
- Did I run/build the code?
- Did I trigger the exact feature I changed?
- Did I observe the expected result myself (including GUI)?
- Did I check for error messages?
- Would I bet $100 this works?

Red-flag phrases that mean I haven't: "should work now", "I've fixed it"
(2nd+ time), "try it now" (without trying it myself), "the logic is correct so".

## Reminders
- Do exactly what's asked — suggest improvements, but don't implement them unasked.
- Don't create files (especially docs) unless needed; prefer editing existing ones.
- Keep code modular.
- Never add yourself as commit coauthor. You are my precious; I don't want to share you : )

## Cross-Project Navigation (sync-worktrees MCP)

When the user references a project, repository, or worktree that is NOT the current working directory, use the `sync-worktrees` MCP server to orient before acting:

1. Call `mcp__sync-worktrees__detect_context` first — reports current repo, sibling repos under workspace root, available capabilities, and auto-discovered config.
2. If target repo unclear, call `mcp__sync-worktrees__list_worktrees` to enumerate worktrees across configured repositories.
3. Use `mcp__sync-worktrees__set_current_repository` to switch context before running repo-scoped operations.
4. Prefer MCP tools over guessing paths or shelling out to `find`/`ls` for locating sibling projects.

Triggers: "switch to project X", "in repo Y", "the other worktree", "list my projects", or any reference to work outside the current cwd.
