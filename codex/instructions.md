# BEGIN MIGRATED FROM CLAUDE
# Migrated global instructions from ~/.claude/CLAUDE.md

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
# END MIGRATED FROM CLAUDE
