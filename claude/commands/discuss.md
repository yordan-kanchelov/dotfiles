Facilitate a multi-round discussion between Claude and OpenAI Codex about a topic.

**Usage:**
- `/discuss <topic>` - Start a discussion (defaults: model=`gpt-5.5`, effort=`xhigh`)
- `/discuss --model <name> --effort <level> <topic>` - Override Codex model and/or reasoning effort
- `/discuss` - I'll ask you for the topic

**Flags (optional, must precede the topic):**
- `--model <name>` (alias `-m`): Codex model. Default `gpt-5.5`. Examples: `gpt-5.5`, `gpt-5.4`, `o3`.
- `--effort <level>` (alias `-e`): reasoning effort. Default `xhigh` (preferred for technical discussions). Valid: `none`, `minimal`, `low`, `medium`, `high`, `xhigh`.

If a flag value is invalid, ask the user to correct it before proceeding (do not silently fall back).

**Workflow:**

1. **Parse arguments:**
   - Read `$ARGUMENTS`. Strip leading `--model <v>` / `-m <v>` and `--effort <v>` / `-e <v>` pairs in any order.
   - Remainder is the topic. If empty, ask: "What topic would you like me to discuss with Codex?"
   - Set `MODEL` (default `gpt-5.5`) and `EFFORT` (default `xhigh` — preferred for technical discussions).
   - Tell the user the chosen model + effort once at the start so they can confirm.

2. **Prepare session directory:**
   - Capture the caller's working directory before creating/running the discussion: `ORIGINAL_CWD="$(pwd -P)"`.
   - If the topic is about a different repo/path than the current cwd, resolve that repo first and set `ORIGINAL_CWD` to that path. Do not run Codex from the discussion directory for repo/code questions.
   - Create a per-session dir: `SESSION_DIR="$HOME/tmp/discuss/$(date +%Y%m%d-%H%M%S)"`. `mkdir -p "$SESSION_DIR"`.
   - Every Codex prompt this session is written to a file under `$SESSION_DIR` (e.g. `round1.txt`, `round2.txt`, …) and fed via stdin. Never inline the prompt as a quoted shell argument — avoids escaping bugs and lets prompts grow large.
   - Tell the user the session dir path once so they can inspect/replay later.

3. **Round 1 — Claude opens:**
   - Share your initial analysis/perspective on the topic (2-3 paragraphs max)
   - Formulate a clear question or challenge for Codex to respond to

4. **Round 1 — Codex responds:**
   Write the full prompt to `$SESSION_DIR/round1.txt` using the Write tool, then feed via stdin:
   ```bash
   codex exec --ephemeral --cd "$ORIGINAL_CWD" --add-dir "$SESSION_DIR" \
     -m "$MODEL" -c model_reasoning_effort="$EFFORT" \
     -o "$SESSION_DIR/round1.codex.txt" - < "$SESSION_DIR/round1.txt"
   ```
   The trailing `-` makes Codex read the prompt from stdin. `--cd "$ORIGINAL_CWD"` lets Codex inspect the actual repo/files, while `--add-dir "$SESSION_DIR"` lets it write the saved reply.
   File contents should be: topic statement, Claude's opening analysis, and the request for Codex's response (agree/disagree, additions, <500 words).
   For code/repo topics, include the repo path, branch/base if relevant, specific file/function pointers, and the claims or questions Codex should verify. Ask Codex to inspect the repo with commands such as `git status`, `git diff`, `rg`, and direct file reads before agreeing. Do not paste large diffs or whole files by default; paste only small excerpts needed to frame the question, or larger context only when the repo is unavailable, generated outside the repo, or explicitly requested by the user.
   - Capture and display Codex's response.
   - Save Codex's reply to `$SESSION_DIR/round1.codex.txt` for later rounds to reference.

5. **Subsequent rounds (up to 5 total):**
   Continue the discussion by alternating:
   - **Claude's turn:** Analyze the latest Codex response, identify agreements/disagreements, add new insights or rebuttals
   - **Codex's turn:** Write the next prompt to `$SESSION_DIR/round<N>.txt` (include the full conversation transcript so far so Codex has context, since `--ephemeral` keeps no session state), then run:
     ```bash
     codex exec --ephemeral --cd "$ORIGINAL_CWD" --add-dir "$SESSION_DIR" \
       -m "$MODEL" -c model_reasoning_effort="$EFFORT" \
       -o "$SESSION_DIR/round<N>.codex.txt" - < "$SESSION_DIR/round<N>.txt"
     ```
     Keep later prompts transcript-focused, but if a new disagreement depends on code, ask Codex to re-open the relevant files or diff from `ORIGINAL_CWD` before taking a position.

   After each round (starting from round 2), evaluate whether the discussion has converged or if new meaningful points are still emerging. End early if:
   - Both sides largely agree and are restating the same points
   - The topic has been thoroughly covered
   - No new insights are being generated

   Otherwise continue up to 5 rounds maximum.

6. **Synthesis:**
   After the final round, provide a summary:
   - **Points of agreement** between Claude and Codex
   - **Points of disagreement** and the reasoning behind each
   - **Key insights** that emerged from the discussion
   - **Conclusion** — a balanced takeaway combining the best of both perspectives

**Formatting:**
- Clearly label each section with who is speaking: `### Claude (Round 1)`, `### Codex (Round 1, gpt-5.5/high)`, etc. Include the model+effort in the Codex header so the chosen settings are visible in the transcript.
- Use blockquotes (`>`) when referencing the other's points
- Keep each round focused and concise

**Notes:**
- If `codex exec` fails (e.g. not authenticated), inform the user and suggest they run `codex` first to sign in
- If `codex exec` fails because `ORIGINAL_CWD` is not a Git repository and the discussion is still valid outside a repo, rerun with `--skip-git-repo-check`. Do not add that flag for repo/code discussions; fix the cwd instead.
- Avoid shell escaping issues by writing prompts to files and reading them via stdin.
- Higher effort (`high`/`xhigh`) costs more tokens and latency — useful for deep architectural debates; `low`/`minimal` is fine for quick sanity checks.
