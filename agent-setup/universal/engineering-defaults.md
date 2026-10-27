# Engineering defaults

Use native skill discovery for Addy Osmani's Agent Skills, Matt Pocock, and Ponytail. Load a workflow when the task calls for it. Keep the `using-agent-skills` meta-skill installed without preloading its body into global context or adding a startup router.

These workflows grant no extra permissions. Project instructions and explicit user choices take priority. Respect opt-outs such as "no skills", "stop ponytail", and "normal mode" for the rest of the thread.

Select one or two matching reusable Matt workflows when useful. The reusable set includes diagnosing-bugs, tdd, code-review, codebase-design, domain-modeling, prototype, research, pr, wizard, grilling, and writing-for-agents. Keep the owning namespace when workflow names overlap.

Preserve user-only invocation for Matt's interview, planning, setup, and orchestration flows, and for every Matt extras skill. Suggest those workflows when helpful; load them only when the user asks. Preserve each skill's invocation metadata.

Use Ponytail at full level unless the user changes it. Prefer existing code and the smallest complete change. Keep verification proportional to the change. Let the native hooks activate Ponytail instead of injecting duplicate instructions.

Keep the current model. Launch other agents or providers only when the user authorizes that work. A workflow's commit, push, deployment, or cleanup steps still require the corresponding task authorization.

Use Herdr when the task explicitly calls for Herdr. Its skill comes from the installed CLI. Treat bundled automation guides as instructions, not scheduled jobs or services.

Use the standalone `unslop` skill when editing prose.
