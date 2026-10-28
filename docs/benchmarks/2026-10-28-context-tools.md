# Context tool benchmarks, 28 October 2026

RTK filters work, but Codex cannot write their tracking or recall databases at the
current macOS paths. The dashboard therefore misses Codex executions. Headroom's
initial conservative configuration works on suitable inputs. Its small percentage
on this workload reflects protected content and a large conversation denominator.

These findings describe RTK 1.1.0 and Headroom 0.42.0. The Headroom baseline is
commit `9b40bc2`, with lossless compression enabled and CCR disabled. Concurrent
configuration edits selected CCR while this audit ran. They were left untouched. Port 8787 later
refused connections, so these results do not validate that newer deployment.

## Dashboard and native hooks

The RTK card initially matched the database exactly: eight executions, 1,139
estimated input tokens, 1,139 output tokens, and zero saved. No oversized commands
were excluded. The card reads retained global history, separate from Headroom's
request totals.

Fresh Claude Code and Codex sessions both rewrote `git status --short` through
their installed RTK hooks. The current Codex app also produced RTK output. In a
fixture-scoped tracking check, Claude added one database row. Codex added none.
Both retained their normal model, sandbox, and trust settings.

Codex could open `history.db` and `recall.db` for reading. Both denied a writable
open with `EPERM`. RTK [silently ignores tracker initialization failures](https://github.com/rtk-ai/rtk/blob/753a3b0e939f2e4490fc24e3a1984010f40a103c/src/core/tracking.rs#L2169-L2177),
so filtering continues without recording savings. Its recall database has the same access gap.
Private writable databases worked in the isolated benchmarks below. That does not
prove recall works from an ordinary Codex session.

The current hook policy also excludes common commands used in this repository,
including searches, Ansible, Python/pytest, and many Git operations. Little eligible
traffic and already-short outputs can produce legitimate zero-saving rows.

## RTK command benchmarks

Each fixture ran once to warm up, followed by three measured runs. Cargo used
offline local fixtures. No packages were installed. Savings here compare visible
UTF-8 output bytes, including any recall hint.

| Command fixture | Raw bytes | RTK bytes | Reduction | Median raw / RTK |
| --- | ---: | ---: | ---: | ---: |
| Git status, 88 paths | 2,084 | 1,839 | 11.8% | 14.8 / 40.0 ms |
| Cargo, 40 passed and 2 failed | 2,051 | 560 | 72.7% | 32.1 / 36.4 ms |
| ESLint, 2 errors and 35 warnings | 6,581 | 715 | 89.1% | 175.8 / 184.2 ms |

Exit codes stayed at 0, 101, and 1. Git retained all 88 paths. Cargo retained both
failure names, messages, and source locations. ESLint kept totals and rule names
but hid 25 of 35 file groups and omitted the undefined identifier
`missing_fixture_name`. An isolated recall check recovered that identifier.
`rtk bypass eslint ...` preserves the command's full output when details matter.

ESLint's percentage depends on absolute path length. An earlier shorter temporary
path produced 85.8%. Native `rtk gain` also measures ESLint's internal JSON input,
which differs from the ordinary stylish output above. Its estimated tokens and
recall-hint accounting therefore differ from visible-output savings.

## Headroom baseline benchmarks

These offline checks exercise the installed message transform pipeline and content
router. The selected model used `EstimatingTokenCounter`, not provider BPE tokens
or RTK's `ceil(bytes/4)` estimate. Counts include the fixture's message envelope.

| Input | Estimated tokens before / after | Reduction | Check |
| --- | ---: | ---: | --- |
| Repeated build log | 5,462 / 104 | 98.1% | Exact repetition expansion |
| Repeated-path search results | 1,613 / 713 | 55.8% | Exact search expansion |
| Same log after frozen history | 32,990 / 27,632 | 16.2% | Frozen message equality |
| Unique log with an error | 1,384 / 1,384 | 0% | Unchanged |
| Pretty JSON, 100 records | 4,046 / 4,046 | 0% | Unchanged |
| Source Read / cat | 1,306 / 1,306; 1,311 / 1,311 | 0% | Read protection |
| Ansible recap / Python error | 116 / 116; 108 / 108 | 0% | Diagnostics retained |
| Protected system prompt | 5,456 / 5,456 | 0% | Unchanged |

The same 5,358 tokens disappear from both log examples. Adding preserved history
changes the percentage. Warm local pipeline medians ranged from 0.08 to 4.25 ms.

A separate structural alternative allowed CCR and disabled model-based compressors.
It reduced the JSON fixture from 4,046 to 1,118 estimated tokens, or 72.4%. A typed
CSV decoder reconstructed all 100 records, fields, and types. This narrow proof
does not establish general accuracy or validate the current production CCR setup.
An isolated tool-schema pass reduced 2,016 to 1,516 estimated tokens, or 24.8%.
Names and required fields survived; annotations can change.

## Do both tools add savings?

All four combinations used identical fixture bytes and the same Headroom counter.
The baseline Headroom configuration added no reduction to these three RTK cases.

| Fixture | Raw bytes | RTK only | Headroom only | Both |
| --- | ---: | ---: | ---: | ---: |
| Git | 2,084 | 1,839 | 2,084 | 1,839 |
| Cargo | 2,051 | 560 | 2,051 | 560 |
| ESLint | 6,581 | 715 | 6,581 | 715 |

Adding RTK and Headroom dashboard counters would mix scopes and estimators. It
would also miss Codex's unrecorded runs. It cannot establish billing savings.

## Why the live percentage was small

The baseline snapshot at 14:59 UTC contained 12 requests and 488 saved tokens.
Session savings were 488 / 1,096,925, or 0.04%. Against 67,420 tokens considered
for compression, the same saving was 0.72%. The new-input metric was 0.74%.
The lifetime view used another denominator: 16,079 / 1,004,976, or 1.60%.
Those percentages should not be compared as if they used the same basis.

Provider cache hits also happen without Headroom. Observed cache discounts do not
measure Headroom's causal contribution.

## Follow-up and reproduction

The first fix should give RTK a private data-only location writable by Codex, such
as `~/tmp/discuss/.rtk-state/`, through its native tracking and retriever database
settings. Render absolute paths per machine. Do not grant write access to the
whole RTK configuration folder. No paths or permissions changed during this audit.
Separately, RTK 1.1.0 ignores the configured seven-day tracking retention and uses
[90 days in its cleanup code](https://github.com/rtk-ai/rtk/blob/753a3b0e939f2e4490fc24e3a1984010f40a103c/src/core/tracking.rs#L908-L913).

Run the saved helpers with installed tools. Both create private temporary artifacts
and reject output locations inside the repository. Headroom blocks network calls.
The component benchmarks make no provider requests; the separate native hook
checks above used the existing CLI logins.

```sh
python3 scripts/benchmarks/rtk.py
# Use the RTK artifact directory printed by the first command.
"$(uv tool dir)/headroom-ai/bin/python" scripts/benchmarks/headroom.py \
  --rtk-fixtures /path/to/rtk-artifacts
```

The [sanitized results](2026-10-28-context-tools.json) include hashes, versions,
timings, and fidelity checks. These synthetic samples do not measure task quality,
provider billing, quota, native transport behavior, or prefix-cache improvements.
Native hook checks cover Claude and Codex. Pi, Hermes, and OpenCode were not
benchmarked or reconfigured. Current CCR deployment remains unverified.
