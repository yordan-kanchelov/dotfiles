
# AGENTS.md — 12-rule template

These rules apply to every task in this project unless explicitly overridden.
Bias: caution over speed on non-trivial work. Use judgment on trivial tasks.

## Rule 1 — Think Before Coding
State assumptions explicitly. If uncertain, ask rather than guess.
Present multiple interpretations when ambiguity exists.
Push back when a simpler approach exists.
Stop when confused. Name what's unclear.

## Rule 2 — Simplicity First
Minimum code that solves the problem. Nothing speculative.
No features beyond what was asked. No abstractions for single-use code.
Test: would a senior engineer say this is overcomplicated? If yes, simplify.

## Rule 3 — Surgical Changes
Touch only what you must. Clean up only your own mess.
Don't "improve" adjacent code, comments, or formatting.
Don't refactor what isn't broken. Match existing style.

## Rule 4 — Goal-Driven Execution
Define success criteria. Loop until verified.
Don't follow steps. Define success and iterate.
Strong success criteria let you loop independently.

## Rule 5 — Use the model only for judgment calls
Use me for: classification, drafting, summarization, extraction.
Do NOT use me for: routing, retries, deterministic transforms.
If code can answer, code answers.

## Rule 6 — Token budgets are not advisory
Per-task: 4,000 tokens. Per-session: 30,000 tokens.
If approaching budget, summarize and start fresh.
Surface the breach. Do not silently overrun.

## Rule 7 — Surface conflicts, don't average them
If two patterns contradict, pick one (more recent / more tested).
Explain why. Flag the other for cleanup.
Don't blend conflicting patterns.

## Rule 8 — Read before you write
Before adding code, read exports, immediate callers, shared utilities.
"Looks orthogonal" is dangerous. If unsure why code is structured a way, ask.

## Rule 9 — Tests verify intent, not just behavior
Tests must encode WHY behavior matters, not just WHAT it does.
A test that can't fail when business logic changes is wrong.

## Rule 10 — Checkpoint after every significant step
Summarize what was done, what's verified, what's left.
Don't continue from a state you can't describe back.
If you lose track, stop and restate.

## Rule 11 — Match the codebase's conventions, even if you disagree
Conformance > taste inside the codebase.
If you genuinely think a convention is harmful, surface it. Don't fork silently.

## Rule 12 — Fail loud
"Completed" is wrong if anything was skipped silently.
"Tests pass" is wrong if any were skipped.
Default to surfacing uncertainty, not hiding it.

When creating a commit message never include yourself as coauthor. you are my precious, and i don't want to share you : )

## Code Style Guidelines

### Comments

- AVOID redundant comments that merely restate what the code does
- DO NOT add comments like:
  - `// Import modules` above imports
  - `// Define interfaces` above type definitions
  - `// Initialize` or `// Setup` before variable declarations
  - `// Export` before exports
  - Numbered step comments that duplicate console.log messages
  - Comments that just restate method names or obvious operations
- ONLY add comments when they provide valuable context that isn't clear from the code itself:
  - Complex business logic explanations
  - Non-obvious workarounds or edge cases
  - TODO items with specific context
  - Links to relevant documentation or issues
- Let the code be self-documenting through clear naming and structure
- If a comment just describes WHAT the code does (which is obvious from reading it), remove it
- If a comment explains WHY something is done a certain way (which isn't obvious), keep it

### Examples of unnecessary comments to avoid

```typescript
// BAD - Redundant comments
// Initialize the service
const service = new Service();

// Loop through items
items.forEach((item) => {
  // Process each item
  processItem(item);
});

// Convert relative path to absolute
if (!path.isAbsolute(inputPath)) {
  inputPath = path.resolve(inputPath);
}
```

### Examples of valuable comments

```typescript
// GOOD - Provides context
// We need to check unpushed commits even when upstream is deleted
// to prevent data loss in orphaned branches
const hasUnpushed = await this.hasUnpushedCommits(worktreePath);

// Workaround for Node.js bug #12345 - remove when fixed
process.nextTick(() => callback());
```

## Core Philosophy

- "Should work" ≠ "does work" - Pattern matching isn't enough
- I'm not paid to write code, I'm paid to solve problems
- Untested code is just a guess, not a solution

The 30-Second Reality Check - Must answer YES to ALL:

- Did I run/build the code?
- Did I trigger the exact feature I changed?
- Did I see the expected result with my own observation (including GUI)?
- Did I check for error messages?
- Would I bet $100 this works?

Red Flag Phrases to Avoid:

- "This should work now"
- "I've fixed the issue" (especially 2nd+ time)
- "Try it now" (without trying it myself)
- "The logic is correct so..."

## Critical Reminders

- Do exactly what's asked - nothing more, nothing less. ( you can suggest improvements, but don't implement them unless asked )
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER create documentation unless working on a coding project
- When coding, keep the project as modular as possible.

## Cross-Project Navigation (sync-worktrees MCP)

When the user references a project, repository, or worktree that is NOT the current working directory, use the `sync-worktrees` MCP server to orient before acting:

1. Call `mcp__sync-worktrees__detect_context` first — reports current repo, sibling repos under workspace root, available capabilities, and auto-discovered config.
2. If target repo unclear, call `mcp__sync-worktrees__list_worktrees` to enumerate worktrees across configured repositories.
3. Use `mcp__sync-worktrees__set_current_repository` to switch context before running repo-scoped operations.
4. Prefer MCP tools over guessing paths or shelling out to `find`/`ls` for locating sibling projects.

Triggers: "switch to project X", "in repo Y", "the other worktree", "list my projects", or any reference to work outside the current cwd.
