# Maintain the agent setup bundle

These instructions cover changes inside `agent-setup/`. Read [README.md](README.md) for installation and [universal/README.md](universal/README.md) for shared package conventions. Read the affected agent's README before changing its manifests or setup steps.

This folder holds portable packages and setup instructions. The Ansible playbook does not deploy it. Follow the repo's [live machine update rule](../AGENTS.md#live-machine-updates) when changing agent configuration or instructions.

## Add or update a skill

1. Check the existing packages and [skill index](universal/skills.md) for the same capability. Select the agents that need the addition.
2. Pin the upstream commit and download that revision. Retain the skill's relative references, scripts, and license files. Keep upstream files byte-for-byte unchanged. Put shared standalone skills in `universal/skills/<name>/` and shared plugin packages in `universal/plugins/<name>/`. Put agent-specific manifests and adapters under `<agent>/plugins/<name>/`.
3. Add or update the component in the appropriate `sources.json`. Shared components belong in [universal/sources.json](universal/sources.json); agent-specific components use that agent's source file. Follow an existing record of the same kind. Record the source URL, revision, version, archive hash, payload path, artifact tree hashes, file counts, and skill count. Standalone skills use `kind: "skill"` and `hosts`; marketplace plugins use `marketplaces` and any `overlays`. Hermes plugins also need `hosts` for staging.
4. Calculate hashes from the reviewed source. `archive_sha256` hashes the downloaded archive bytes. Artifact hashes follow `check_sources` in [the bundle script](../scripts/agent-setup-bundle.py): sort retained files by path, then hash each relative POSIX path, a NUL byte, and the binary SHA-256 digest of its contents. Keep payloads as ordinary files. A hash mismatch requires investigating the source or an intentional version update; do not change a pin merely to accept unexplained drift.
5. Update the shared package list and affected agent READMEs. Preserve any existing plugin namespace and document intentional changes. Extend staging tests for the new package or affected agents. Adjust expected counts only for intentional additions or removals. Machine inventories are dated snapshots; update them only when taking a new inventory.

Keep host-specific adaptations separate from shared upstream files. Herdr's skill comes from its installed CLI. Account-managed plugins, synced skills, and system skills remain managed by their hosts.

## What the scripts do

Both scripts live in the repository's `scripts/` directory and resolve `agent-setup/` relative to their own location.

- [agent-setup-bundle.py](../scripts/agent-setup-bundle.py) checks source integrity by default. It does not update source pins or artifact hashes. `--stage <agent> --output <new-directory>` assembles packages using ordinary copies. It refuses existing output directories and never installs into a user profile or runs bundled hooks.
- [test-agent-setup-bundle.py](../scripts/test-agent-setup-bundle.py) checks package completeness, detector execution, rejection of changed sources, preservation of existing output, and Git line endings. Fixtures use temporary directories and leave live agent profiles alone.

Use the scripts for repeatable checks and package assembly. Agents handle source selection, adapter review, setup prose, and inventory collection. Keep executable checks for the results.

## Verify a change

Run from the repository root after updating the source records:

```sh
python3 scripts/agent-setup-bundle.py
python3 scripts/test-agent-setup-bundle.py
```

Check the diff for unintended payload or inventory changes. Update `universal/skills.md`, the inventories, and the README overview by hand. CI runs the checker and tests; its ShellCheck scan excludes pinned upstream plugins so their bytes stay unchanged.

For changed docs and skills, use `unslop` to revise prose, then run the bundled Sloptrim detector on each saved file. Preserve quotations, code, and upstream skill bodies. Review flagged spans rather than changing text solely to lower a score. An install check should also confirm native skill discovery after restarting or reloading the affected agent.
