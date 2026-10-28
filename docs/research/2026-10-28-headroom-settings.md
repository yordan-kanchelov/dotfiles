# Headroom settings and companion plugins

Reviewed on 2026-10-28 for our Claude Code and Codex workflow. Source defaults were checked at commit `f10725e6b9940d8bc2fcde950c86f8ac97543cb6`. Cached documentation sometimes describes older behavior. No `headroom` executable was found on this shell's PATH. No installation or agent-profile changes were made.

The later [installed setup](../../agent-setup/context-tools/README.md) records the active service and agent settings. It sets CCR retention to 3600 seconds at the user's request. CCR remains disabled during the lossless trial. Full-message logging is enabled with local rotation, though Headroom 0.42.0 leaves response bodies empty. The tables below describe the source review; use the installed setup for current choices.

Start with `coding`, `cache`, and lossless compaction. Then compare normal CCR compression on matched tasks. Keep file reads and instructions protected. Leave memory, learning, code graphs, output shaping, and remote compression out of that first comparison. Recommendations below are ours; default values describe the cited source revision.

The runtime inventory covers public options for the proxy, Claude/Codex wrappers, deployment, and MCP. Compression tables explain the profile controls and direct SDK settings. Related constructor fields share rows. This is not an inventory of private developer switches or every option for other agent integrations.

For screenshots and UI work, preserve image detail. There is no verified dedicated image-disable CLI flag in the inspected entry point. The compressor allowlist can exclude the image arm. To retain the other built-in arms, use `HEADROOM_COMPRESSORS=smart_crusher,kompress,code_aware,search,log,tabular,config,html`. Test this selection with the installed version before relying on it.

Headroom's caches have different jobs. Provider prompt caching reuses inference computation. CCR retains originals for retrieval. Local response caching can replay an answer. The compressed-result cache avoids repeating local compression. Changing one does not disable the others.

## Runtime and first trial

Use a wrapped terminal session. Keep the coding profile and cache mode. Keep retrieval available. Skip memory, live learning, code graphs, and a second code-navigation server until compression has proved useful on our tasks.

```sh
HEADROOM_BEACON=off \
HEADROOM_UPDATE_CHECK=off \
HEADROOM_ROLLOUT_CHANNEL=stable \
HEADROOM_DISABLE_FEATURES=proxy_output_shaper,tool_result_interceptors,read_maturation \
HEADROOM_SAVINGS_PROFILE=coding \
HEADROOM_LOSSLESS=1 \
HEADROOM_MODE=cache \
headroom wrap claude --code-memory none
```

For Codex, use the same environment with `headroom wrap codex --code-memory none`. These are source-checked command forms, not a tested deployment. `wrap` still registers Headroom's retrieval MCP and can write client settings. Do not use `--no-mcp` with ordinary lossy compression. The proposed baseline sets `HEADROOM_LOSSLESS=1`. For a later ordinary CCR trial, unset it and keep retrieval available.

The wrapper reuses an existing healthy proxy. An existing process may retain earlier settings. Verify the running settings and `/stats.rollout`, or use a fresh proxy. Some legacy output settings hot-sync globally through `/admin/runtime-env`; one session can affect other users of that proxy.

## Decisions that affect our workflow

| Setting | Default | Purpose | Recommendation |
|---|---|---|---|
| Proxy `--mode` / `HEADROOM_MODE` | `cache` | Compress new content while preserving the sent prefix | Keep `cache`. Compare billed tokens and cache hits, not only raw compression. |
| `HEADROOM_SAVINGS_PROFILE` | `coding` | Seed a group of compression settings | Keep `coding`; targets are policy/display values, not promised savings. |
| SDK `default_mode` / `headroom_mode` | Constructor/per-call setting | `audit`, `optimize`, or `simulate` | These are not proxy modes and are not valid values for proxy `--mode`. |
| `--code-memory` / `HEADROOM_CODE_MEMORY` | `serena` | Register and prepare Serena MCP | Use `none` while evaluating compression beside our existing tools. |
| `--code-memory-scope` / `HEADROOM_CODE_MEMORY_SCOPE` | `project` | Scope Claude's Serena registration | Keep project scope if Serena is later enabled. Codex registration is in its active config. |
| `--serena-instructions` / `HEADROOM_SERENA_INSTRUCTIONS` | Off | Insert Serena guidance into agent instruction files | Leave off. |
| Claude `--tool-search` | `true` unless existing `ENABLE_TOOL_SEARCH` wins | Preserve Claude's native deferred tool loading after changing the base URL | Keep native deferral. This is distinct from Headroom's own tool-schema compression. |
| `HEADROOM_TOOL_SEARCH` | On in coding profile | Proxy-managed tool-schema deferral | Compare with native tool search; set `0` if duplicate tool discovery causes trouble. |
| `--memory` | Off | Cross-session memory and extra memory tools | Leave off for the first trial. |
| `--learn` | Off | Derive and persist patterns from traffic; implies memory | Leave off; it can edit memory and instruction files. |
| `--memory-storage` | `project` | Partition memory databases | Keep project isolation if memory is later enabled. |
| `--code-graph` | Off | Start a project code-index watcher | Leave off; assess Serena before adding another index. |
| `--intercept-tool-results` | Off, canary-gated | Rewrite reads through interceptors | Leave off for the first trial. |
| `--read-maturation` | Off, beta-gated | Compress reads after file activity stops | Leave off for the first trial. |
| Output shaper feature | Off, available in stable | Append verbosity steering to prompts | Explicitly disable `proxy_output_shaper` during comparison with our Ponytail instructions. |
| `HEADROOM_BEACON` | On | Upload anonymous token/model/runtime counters | Set `off` for work repositories. No prompt contents are documented in this beacon. |
| `HEADROOM_TELEMETRY` / `--telemetry` | Off | Enable local dashboard/metrics stats | Optional. `--no-telemetry` also disables beacon unless beacon is explicitly forced on. |
| `HEADROOM_UPDATE_CHECK` | On | Check PyPI daily for update notices | Set `off` if updates belong to our package management. This is a notice check, not automatic installation. |
| `HEADROOM_OFFLINE` | Off | Block Headroom-initiated external connections | Use only with required models already cached. It still permits forwarding client calls to their configured upstream. |
| `--no-subscription-tracking` | False, tracking enabled | Poll Claude account usage | Keep tracking only if quota visibility helps; polling defaults to every 300 seconds. |
| `--log-messages` | Off | Requests full message logging | Enabled at the user's request. Installed 0.42.0 records original and compressed requests but omits response bodies. |
| `HEADROOM_LOG_PAYLOAD_PREVIEW` | Off | Log retrieved content snippets | Leave off to avoid retaining source or secrets in logs. |
| `HEADROOM_PROXY_TOKEN` | Unset | Authenticate non-loopback proxy callers | Keep loopback binding; add a token before exposing the port. |
| `HEADROOM_TLS_STRICT` | Strict | Upstream TLS certificate constraints | Keep strict. Add corporate roots through the trust configuration. |
| `HEADROOM_STRIP_INTERNAL_HEADERS` | Enabled | Remove private Headroom headers before forwarding | Keep enabled. |
| `--workers` | 1 | Run multiple server processes | Keep 1; some settings and tracker state are process-local. |
| `--rpm` | 60 | Proxy-local request limit | Watch for concurrent-agent bursts; raise only if this limit causes extra 429s. |
| `--budget` | Unset | Enforce a proxy-local dollar budget | Optional for metered APIs; it does not represent subscription quota. |
| `--stateless` | Off | Keep proxy state in memory | Optional for disposable trials; wrapper edits still persist separately. |

## Auth and durable changes

Claude uses its existing credentials through a local base URL. Setting a custom base URL affects native tool search and Remote Control. The wrapper sets native tool search explicitly. `--1m` selects a model with a `[1m]` suffix; it cannot grant account eligibility. Leave it off unless the model and plan already support the window.

Current Codex wrapping uses the real `CODEX_HOME`, preserves the selected provider ID, and passes routing through process-local `--config` overrides. Native `openai` uses `openai_base_url`; custom providers get their `base_url` redirected and the original upstream forwarded in a header. Source comments say these command-line overrides select embedded operation, without the shared background server. This differs from older wrappers that used temporary homes. The proxy detects ChatGPT OAuth headers/token claims and forwards subscription requests to ChatGPT. No new API key is required by this route. This is implementation evidence, not a live entitlement test.

A normal Codex wrap still installs retrieval MCP into its active config. `--memory` can add memory guidance to project `AGENTS.md` and import Claude memories. `--code-memory none` skips Serena, not Headroom retrieval.

Both `wrap` and `unwrap` run a migration that removes retired Headroom-managed `rtk` / `lean-ctx` hooks, binaries, symlinks, MCP registrations, and instruction fences. It verifies a path into Headroom's managed bin directory before removing registrations. User-owned installations are preserved. Global cleanup runs once; project-specific fenced guidance is checked each invocation. There is no public opt-out. Retired `--context-tool`, `--no-context-tool`, and `HEADROOM_CONTEXT_TOOL` now raise an error. Help and self-heal skip this migration.

## Precedence and persistence

CLI flags override environment values. Shell exports beat `settings.json`, whose registered values fill unset environment entries. Savings profiles fill their own unset settings. A direct proxy's mode resolves as CLI `--mode`, then `HEADROOM_MODE`, then `cache`; choosing a token-oriented profile alone does not change this final direct-proxy fallback.

The settings GUI stores a registered subset of settings, not an arbitrary `ProxyConfig` JSON document. `HEADROOM_TLS_STRICT`, `HEADROOM_BEACON`, `HEADROOM_CCR_BACKEND`, and `HEADROOM_OFFLINE` cannot be set through that registry. Do not copy Python dataclass fields into client TOML or invent CLI JSON syntax.

State uses `HEADROOM_WORKSPACE_DIR`, default `~/.headroom`. Configuration uses `HEADROOM_CONFIG_DIR`, default `~/.headroom/config`. Per-resource path overrides win. Memory defaults to project-local `.headroom/`; it does not always follow the workspace override. Settings, originals, memory, logs, and stored provider-header maps are plaintext. Ordinary runtime logs rotate; opt-in request dumps need separate retention care.

Runtime channels are `stable`, `beta`, `canary`, and `dev`. `HEADROOM_FEATURES` requests named features; `HEADROOM_DISABLE_FEATURES` wins over every enable mechanism. `HEADROOM_UNSAFE_ALLOW_UNSTABLE_FEATURES` can cross channel bounds and should remain unset. Channels change feature availability within an installed version; they do not select or update the package.

## CLI option inventory

The following tables list every public option on the relevant commands at the checked revision. Hidden internal options are excluded. Public deprecated aliases remain listed and marked. Where Click uses `None`, the effective default comes from environment, profile, or runtime resolution; it is not a claim that the feature is disabled. The purpose column summarizes each setting. Keep defaults unless a recommendation above says otherwise.

### proxy

Source: [headroom/cli/proxy.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cli/proxy.py).

| Option | Default | Environment | Purpose |
|---|---|---|---|
| `--host` | `127.0.0.1` | `HEADROOM_HOST` | Bind the server to this address. |
| `--uds` | `Unset / runtime` | `HEADROOM_UDS` | Listen on a Unix socket instead of TCP. POSIX only. |
| `--port / -p` | `8787` | `HEADROOM_PORT` | Choose the proxy TCP port. |
| `--workers` | `1` | `HEADROOM_WORKERS` | Run this many Uvicorn processes. |
| `--limit-concurrency` | `1000` | `HEADROOM_LIMIT_CONCURRENCY` | Reject excess concurrent connections with 503. |
| `--max-connections` | `500` | `HEADROOM_MAX_CONNECTIONS` | Cap upstream HTTP connections. |
| `--max-keepalive` | `100` | `HEADROOM_MAX_KEEPALIVE` | Cap idle reusable upstream connections. |
| `--http2/--no-http2` | `True` | `HEADROOM_HTTP2` | Enable or disable HTTP/2 for upstream requests. |
| `--http-proxy` | `Unset / runtime` | `HEADROOM_HTTP_PROXY` | Route provider API calls through this HTTP proxy. |
| `--keepalive-expiry` | `90.0` | `HEADROOM_KEEPALIVE_EXPIRY` | Retire idle upstream connections after this many seconds. |
| `--mode` | `cache` | `HEADROOM_MODE` | Use cache mode for a stable prefix, or token mode to rewrite older turns. |
| `--target-ratio` | `Unset / runtime` | `HEADROOM_TARGET_RATIO` | Set the fraction of text tokens Kompress should retain. |
| `--intercept-tool-results` | `False` | - | Enable canary tool-result rewriting. |
| `--no-optimize` | `False` | - | Forward traffic without compression. |
| `--no-cache` | `False` | - | Disable semantic caching. |
| `--no-rate-limit` | `False` | - | Disable the proxy-local rate limiter. |
| `--protect-tool-results` | `Unset / runtime` | `HEADROOM_PROTECT_TOOL_RESULTS` | Add tool names whose results must avoid lossy compression. |
| `--rpm` | `60` | `HEADROOM_RPM` | Limit requests per minute. |
| `--tpm` | `Unlimited` | `HEADROOM_TPM` | Limit tokens per minute. |
| `--no-ccr` | `False` | `HEADROOM_NO_CCR` | Disable retrieval markers and the retrieval tool. Lossy output has no recovery path. |
| `--lossless` | `False` | `HEADROOM_LOSSLESS` | Use marker-free format compaction without a retrieval tool. |
| `--ccr-inline-resolve` | `False` | `HEADROOM_CCR_INLINE_RESOLVE` | Expand retrieval markers inside non-streaming responses. |
| `--no-ccr-proactive-expansion` | `False` | `HEADROOM_NO_CCR_PROACTIVE_EXPANSION` | Stop automatic expansion of earlier compressed content. |
| `--proxy-extension` | `None` | `HEADROOM_PROXY_EXTENSIONS` | Enable named registered extensions. Repeat the flag for several names. |
| `--compressor` | `All built-ins` | `HEADROOM_COMPRESSORS` | Select the allowed built-in compressors. |
| `--no-subscription-tracking` | `False` | `HEADROOM_NO_SUBSCRIPTION_TRACKING` | Stop polling Claude account usage. |
| `--subscription-poll-interval` | `300 s` | `HEADROOM_SUBSCRIPTION_POLL_INTERVAL` | Set seconds between Claude subscription-usage polls. |
| `--retry-max-attempts` | `3` | `HEADROOM_RETRY_MAX_ATTEMPTS` | Cap upstream attempts after transient failures. |
| `--retry-base-delay-ms` | `1000 ms` | `HEADROOM_RETRY_BASE_DELAY_MS` | Set the initial retry delay in milliseconds. |
| `--retry-max-delay-ms` | `30000 ms` | `HEADROOM_RETRY_MAX_DELAY_MS` | Cap retry delays in milliseconds. |
| `--request-timeout-seconds` | `300 s` | `HEADROOM_REQUEST_TIMEOUT` | Set the upstream request timeout in seconds. |
| `--connect-timeout-seconds` | `10 s` | `HEADROOM_CONNECT_TIMEOUT_SECONDS` | Set the upstream connection timeout in seconds. |
| `--write-timeout-seconds` | `150 s` | `HEADROOM_WRITE_TIMEOUT_SECONDS` | Limit time spent sending an upstream request body. |
| `--upstream-tcp-keepalive-seconds` | `30 s` | `HEADROOM_UPSTREAM_TCP_KEEPALIVE_SECONDS` | Start TCP keepalive probes after this much idle time. Zero disables probes. |
| `--anthropic-buffered-request-timeout-seconds` | `600 s` | `HEADROOM_ANTHROPIC_BUFFERED_REQUEST_TIMEOUT_SECONDS` | Set the read timeout for buffered Anthropic requests. |
| `--anthropic-pre-upstream-concurrency` | `max(2,min(8,CPU count or 4))` | `HEADROOM_ANTHROPIC_PRE_UPSTREAM_CONCURRENCY` | Cap concurrent Anthropic parsing, compression, memory lookup, and connect work. |
| `--anthropic-pre-upstream-acquire-timeout-seconds` | `15 s` | `HEADROOM_ANTHROPIC_PRE_UPSTREAM_ACQUIRE_TIMEOUT_SECONDS` | Stop waiting for a preparation slot after this timeout; allow passthrough. |
| `--anthropic-pre-upstream-memory-context-timeout-seconds` | `2 s` | `HEADROOM_ANTHROPIC_PRE_UPSTREAM_MEMORY_CONTEXT_TIMEOUT_SECONDS` | Bound memory lookup while holding an Anthropic preparation slot. |
| `--compression-max-workers` | `CPU count, minimum 1` | `HEADROOM_COMPRESSION_MAX_WORKERS` | Cap threads doing CPU-bound compression. |
| `--log-file` | `Unset / runtime` | `HEADROOM_LOG_FILE` | Write per-request JSONL records to this file. |
| `--log-messages` | `False` | `HEADROOM_LOG_MESSAGES` | Include full messages in request logs and the live feed. |
| `--codex-wire-debug` | `False` | - | Save local Codex wire snapshots and frame traces. |
| `--codex-wire-debug-dir` | `Unset / runtime` | - | Choose the directory for Codex wire snapshots. |
| `--budget` | `Unset / runtime` | `HEADROOM_BUDGET` | Reject requests with 429 when booked spend reaches this USD limit. |
| `--budget-period` | `daily` | `HEADROOM_BUDGET_PERIOD` | Apply the budget hourly, daily, or monthly. |
| `--budget-estimated-basis` | `count` | `HEADROOM_BUDGET_ESTIMATED_BASIS` | Count estimated spend, ignore it, or block requests whose cost requires an estimate. |
| `--code-aware/--no-code-aware` | `Inherit; coding profile enables it` | `HEADROOM_CODE_AWARE_ENABLED` | Override AST code compression. Requires optional parsing dependencies. |
| `--disable-kompress` | `False` | `HEADROOM_DISABLE_KOMPRESS` | Disable normal Kompress routing while retaining structural compressors. |
| `--disable-kompress-fallback` | `False` | `HEADROOM_DISABLE_KOMPRESS_FALLBACK` | Also disable the Kompress fallback when normal Kompress routing is disabled. |
| `--disable-kompress-anthropic/--enable-kompress-anthropic` | `Unset / runtime` | `HEADROOM_DISABLE_KOMPRESS_ANTHROPIC` | Override Kompress for Anthropic requests. |
| `--disable-kompress-openai/--enable-kompress-openai` | `Unset / runtime` | `HEADROOM_DISABLE_KOMPRESS_OPENAI` | Override Kompress for OpenAI and Codex requests. |
| `--code-graph` | `False` | - | Index the current project and watch files for changes. |
| `--no-read-lifecycle` | `False` | - | Stop replacing stale and superseded reads. |
| `--read-maturation` | `False` | `HEADROOM_READ_MATURATION` | Enable beta read maturation after file activity stops. |
| `--read-maturation-quiesce-turns` | `5` | `HEADROOM_READ_MATURATION_QUIESCE_TURNS` | Wait this many quiet assistant turns before maturing a held read. |
| `--read-maturation-max-hold-turns` | `25` | `HEADROOM_READ_MATURATION_MAX_HOLD_TURNS` | Mature a read after this many turns despite continued file activity. |
| `--read-maturation-min-size-bytes` | `2048` | `HEADROOM_READ_MATURATION_MIN_SIZE_BYTES` | Only mature reads at least this many bytes long. |
| `--memory` | `False` | - | Enable persistent cross-session memory. |
| `--memory-db-path` | `cwd/.headroom/memory.db` | `HEADROOM_MEMORY_DB_PATH` | Choose the memory DB path or the seed directory for partitioned storage. |
| `--memory-storage` | `project` | - | Partition memory per project, per user, or in one global database. |
| `--memory-project-root` | `Inferred from request or current project` | `HEADROOM_MEMORY_PROJECT_ROOT` | Set the project root when headers do not already identify one. |
| `--no-memory-tools` | `False` | `HEADROOM_NO_MEMORY_TOOLS` | Stop injecting memory save and search tools. |
| `--no-memory-context` | `False` | `HEADROOM_NO_MEMORY_CONTEXT` | Stop automatic memory context insertion. |
| `--memory-top-k` | `10` | `HEADROOM_MEMORY_TOP_K` | Limit memories selected for automatic context. |
| `--memory-qdrant-url` | `Unset / runtime` | `HEADROOM_QDRANT_URL` | Choose the full Qdrant URL; override separate host and port settings. |
| `--memory-qdrant-host` | `localhost` | `HEADROOM_QDRANT_HOST` | Set the Qdrant host. |
| `--memory-qdrant-port` | `6333` | `HEADROOM_QDRANT_PORT` | Set the Qdrant port. |
| `--memory-qdrant-api-key` | `Unset / runtime` | `HEADROOM_QDRANT_API_KEY` | Authenticate to hosted Qdrant. |
| `--learn` | `False` | - | Learn error and recovery patterns, environment facts, and preferences from traffic. |
| `--no-learn` | `False` | - | Disable live learning. |
| `--min-evidence` | `5` | `HEADROOM_MIN_EVIDENCE` | Require this many observations before saving a learned pattern. |
| `--backend` | `anthropic` | `HEADROOM_BACKEND` | Select the provider adapter. |
| `--anyllm-provider` | `openai` | `HEADROOM_ANYLLM_PROVIDER` | Choose the provider used by the any-llm adapter. |
| `--anthropic-api-url` | `Anthropic default` | `ANTHROPIC_TARGET_API_URL` | Override the Anthropic upstream URL. |
| `--openai-api-url` | `https://api.openai.com` | `OPENAI_TARGET_API_URL` | Override the OpenAI-compatible upstream URL. |
| `--provider-name` | `Unset / runtime` | - | Change the displayed provider name without changing routing. |
| `--gemini-api-url` | `Gemini default` | `GEMINI_TARGET_API_URL` | Override the Gemini upstream URL. |
| `--cloudcode-api-url` | `Unset / runtime` | `CLOUDCODE_TARGET_API_URL` | Override the Cloud Code Assist upstream URL. |
| `--vertex-api-url` | `Unset / runtime` | `VERTEX_TARGET_API_URL` | Override the Vertex upstream URL. |
| `--region` | `us-west-2` | `HEADROOM_REGION` | Set the cloud region. |
| `--bedrock-region` | `Unset / runtime` | - | Deprecated alias for the Bedrock region; use --region. |
| `--bedrock-profile` | `Unset / runtime` | - | Choose an AWS credential profile. |
| `--bedrock-api-url` | `Unset / runtime` | `BEDROCK_TARGET_API_URL` | Route Bedrock calls through a gateway that can re-sign changed requests. |
| `--telemetry` | `False` | `HEADROOM_TELEMETRY` | Enable local usage statistics. Outbound beacon control is separate. |
| `--no-telemetry` | `False` | `HEADROOM_TELEMETRY` | Disable local usage statistics and the outbound beacon, subject to explicit beacon override. |
| `--stateless` | `False` | `HEADROOM_STATELESS` | Keep proxy runtime state in memory. Wrapper edits remain separate. |
| `--embedding-server/--no-embedding-server` | `False` | `HEADROOM_EMBEDDING_SERVER` | Share one embedding process across workers. |
| `--embedding-server-socket` | `Unset / runtime` | `HEADROOM_EMBEDDING_SERVER_SOCKET` | Choose the embedding process Unix socket. |
| `--anthropic-extra-headers` | `Unset / runtime` | `ANTHROPIC_TARGET_API_HEADERS` | Merge operator-supplied headers into requests to approved Anthropic targets. |
| `--openai-extra-headers` | `Unset / runtime` | `OPENAI_TARGET_API_HEADERS` | Merge operator-supplied headers into requests to approved OpenAI targets. |

### claude

Source: [headroom/cli/wrap.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cli/wrap.py).

| Option | Default | Environment | Purpose |
|---|---|---|---|
| `--no-mcp` | `False` | - | Skip retrieval MCP registration; ordinary CCR markers then cannot be redeemed. |
| `--code-graph` | `False` | - | Index the current project and watch files for changes. |
| `--no-proxy` | `False` | - | Reuse an existing proxy without starting one. |
| `--project-settings / --project-settings-injection` | `False` | `HEADROOM_CLAUDE_PROJECT_SETTINGS` | Write project-local Claude routing for workers started by a daemon. |
| `--learn` | `False` | - | Learn error and recovery patterns, environment facts, and preferences from traffic. |
| `--memory` | `False` | - | Enable persistent cross-session memory. |
| `--tool-search` | `true unless ENABLE_TOOL_SEARCH is set` | - | Keep Claude native deferred tool loading active through the proxy. |
| `--backend` | `Unset / runtime` | `HEADROOM_BACKEND` | Select the provider adapter. |
| `--region` | `Unset / runtime` | `HEADROOM_REGION` | Set the cloud region. |
| `--1m` | `False` | - | Select a model with a [1m] suffix. Account eligibility still applies. |
| `--verbose / -v` | `False` | - | Print more operational detail. |

### codex

Source: [headroom/cli/wrap.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cli/wrap.py).

| Option | Default | Environment | Purpose |
|---|---|---|---|
| `--no-mcp` | `False` | - | Skip retrieval MCP registration; ordinary CCR markers then cannot be redeemed. |
| `--code-graph` | `False` | - | Index the current project and watch files for changes. |
| `--no-proxy` | `False` | - | Reuse an existing proxy without starting one. |
| `--learn` | `False` | - | Learn error and recovery patterns, environment facts, and preferences from traffic. |
| `--backend` | `Unset / runtime` | `HEADROOM_BACKEND` | Select the provider adapter. |
| `--anyllm-provider` | `Unset / runtime` | `HEADROOM_ANYLLM_PROVIDER` | Choose the provider used by the any-llm adapter. |
| `--region` | `Unset / runtime` | `HEADROOM_REGION` | Set the cloud region. |
| `--memory` | `False` | - | Enable persistent cross-session memory. |
| `--verbose / -v` | `False` | - | Print more operational detail. |

### deploy

Source: [headroom/cli/install.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cli/install.py).

| Option | Default | Environment | Purpose |
|---|---|---|---|
| `--profile` | `default` | - | Select the deployment profile. |
| `--port / -p` | `8787` | `HEADROOM_PORT` | Choose the proxy TCP port. |
| `--backend` | `anthropic` | - | Select the provider adapter. |
| `--anyllm-provider` | `Unset / runtime` | - | Choose the provider used by the any-llm adapter. |
| `--region` | `Unset / runtime` | - | Set the cloud region. |
| `--mode` | `cache` | - | Use cache mode for a stable prefix, or token mode to rewrite older turns. |
| `--scope` | `user` | - | Choose provider, user, or system configuration edits. |
| `--providers` | `auto` | - | Detect targets automatically, configure all, or use explicit targets. |
| `--target` | `Unset` | - | Select one tool to configure. Repeat with manual provider selection. |
| `--memory` | `False` | - | Enable persistent cross-session memory. |
| `--telemetry` | `False` | - | Enable local usage statistics. Outbound beacon control is separate. |
| `--no-telemetry` | `False` | - | Disable local usage statistics and the outbound beacon, subject to explicit beacon override. |
| `--image` | `ghcr.io/headroomlabs-ai/headroom:latest` | - | Choose the Docker image. |
| `--no-docker` | `False` | - | Use Python even when Docker is available. |
| `--no-http2` | `False` | - | Use HTTP/1.1 for upstream requests. |

### install apply

Source: [headroom/cli/install.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cli/install.py).

| Option | Default | Environment | Purpose |
|---|---|---|---|
| `--preset` | `persistent-service` | - | Select a persistent service, watchdog task, or Docker container. |
| `--runtime` | `python` | - | Run Python directly or use Docker. |
| `--scope` | `user` | - | Choose provider, user, or system configuration edits. |
| `--providers` | `auto` | - | Detect targets automatically, configure all, or use explicit targets. |
| `--target` | `Unset` | - | Select one tool to configure. Repeat with manual provider selection. |
| `--profile` | `default` | - | Select the deployment profile. |
| `--port / -p` | `8787` | `HEADROOM_PORT` | Choose the proxy TCP port. |
| `--backend` | `anthropic` | - | Select the provider adapter. |
| `--anyllm-provider` | `Unset / runtime` | - | Choose the provider used by the any-llm adapter. |
| `--region` | `Unset / runtime` | - | Set the cloud region. |
| `--mode` | `cache` | - | Use cache mode for a stable prefix, or token mode to rewrite older turns. |
| `--memory` | `False` | - | Enable persistent cross-session memory. |
| `--telemetry` | `False` | - | Enable local usage statistics. Outbound beacon control is separate. |
| `--no-telemetry` | `False` | - | Disable local usage statistics and the outbound beacon, subject to explicit beacon override. |
| `--no-rate-limit` | `False` | - | Disable the proxy-local rate limiter. |
| `--image` | `ghcr.io/headroomlabs-ai/headroom:latest` | - | Choose the Docker image. |
| `--no-http2` | `False` | - | Use HTTP/1.1 for upstream requests. |
| `--code-aware/--no-code-aware` | `Inherit; coding profile enables it` | - | Override AST code compression. Requires optional parsing dependencies. |
| `--intercept-tool-results` | `False` | - | Enable canary tool-result rewriting. |
| `--protect-tool-results` | `Unset / runtime` | - | Add tool names whose results must avoid lossy compression. |
| `--bedrock-profile` | `Unset / runtime` | - | Choose an AWS credential profile. |
| `--env` | `Unset` | - | Set a supervised-process environment variable as KEY=VALUE. Repeat as needed. |

### mcp install

Source: [headroom/cli/mcp.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cli/mcp.py).

| Option | Default | Environment | Purpose |
|---|---|---|---|
| `--proxy-url` | `http://127.0.0.1:8787` | - | Connect this MCP server to the Headroom proxy at this URL. |
| `--agent` | `Unset` | - | Restrict MCP installation to named agents. Otherwise detect all supported agents. |
| `--force` | `False` | - | Replace an existing mismatched Headroom MCP registration. |

### mcp serve

Source: [headroom/cli/mcp.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cli/mcp.py).

| Option | Default | Environment | Purpose |
|---|---|---|---|
| `--proxy-url` | `http://127.0.0.1:8787` | `HEADROOM_PROXY_URL` | Connect this MCP server to the Headroom proxy at this URL. |
| `--transport` | `stdio` | - | Serve MCP over stdio or HTTP. |
| `--host` | `127.0.0.1` | - | Bind the HTTP MCP server to this address. |
| `--port` | `8788` | - | Listen on this HTTP MCP port. |
| `--path` | `/mcp` | - | Choose the HTTP MCP route. |
| `--direct` | `False` | - | Deprecated flag with no effect. |
| `--debug` | `False` | - | Enable debug logs. |

### Shared wrapper options

| Option | Default | Purpose | Recommendation |
|---|---|---|---|
| `--port` / `HEADROOM_PORT` | Discover existing managed proxy, else 8787 | Select proxy instance | Use a deliberate port for comparison runs. |
| `--code-memory serena/none` | `serena` | Add code-navigation MCP | Use `none` initially. |
| `--code-memory-scope project/user` | `project` | Claude Serena registration scope | Keep project scope. |
| `--serena-instructions` | False | Write Serena guidance into instruction files | Leave off. |
| `--no-proxy` | False | Use an existing proxy | Reuse an existing proxy without starting one. |
| `--no-mcp` | False | Skip Headroom retrieval registration | Skip retrieval MCP registration; ordinary CCR markers then cannot be redeemed. |
| `--` followed by agent args | Empty | Pass model/prompt/session args through | Use the existing agent model/settings. |

Source help still describes AST code compression as disabled, but the checked CLI runtime uses `HEADROOM_CODE_AWARE_ENABLED` with fallback `1`, and the coding profile sets it to `1`. Treat the flag as a tri-state override. `--no-code-aware` explicitly turns it off.

## Additional documented environment settings

This inventory combines the public proxy/configuration tables and excludes variables already paired with CLI flags above. Compressor-specific detail appears in the compression tables below. Defaults here retain the documentation's scope; profile defaults may override base defaults.

Source: [docs/content/docs/configuration.mdx](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/docs/content/docs/configuration.mdx).

| Setting | Documented default | Purpose |
|---|---|---|
| `HEADROOM_ROLLOUT_CHANNEL` | `stable` | Select stable, beta, canary, or dev runtime features. |
| `HEADROOM_FEATURES` | Unset | Request named runtime features. |
| `HEADROOM_DISABLE_FEATURES` | Unset | Force named runtime features off. |
| `HEADROOM_UNSAFE_ALLOW_UNSTABLE_FEATURES` | Unset | Allow requested features outside the selected rollout channel. |
| `HEADROOM_MODE` | `cache` | Proxy optimization mode: `token` or `cache` |
| `HEADROOM_TELEMETRY` | `off` | Set to `on` for **local-only** usage stats (powers your own `/stats` and dashboard; nothing is sent externally) |
| `HEADROOM_STATELESS` | `false` | Set to `true` to disable filesystem writes |
| `HEADROOM_MODEL_LIMITS` | -- | Custom model config (JSON string or file path) |
| `HEADROOM_LOSSLESS_COMPACTION` | `1` | Set to `0` to disable the byte-reversible lossless folds (grep heading, log run-collapse, diff/config folds) while leaving the rest of the compression pipeline active. |
| `HEADROOM_BASE_URL` | `http://localhost:8787` | Base URL of the Headroom proxy (TypeScript SDK) |
| `HEADROOM_API_KEY` | -- | Optional API key for authenticated Headroom endpoints (TypeScript SDK) |
| `HEADROOM_CONFIG_DIR` | `~/.headroom/config` | Canonical config (read-mostly) root. |
| `HEADROOM_WORKSPACE_DIR` | `~/.headroom` | Canonical workspace (read-write state) root. |
| `HEADROOM_SAVINGS_PATH` | derived from `${HEADROOM_WORKSPACE_DIR}` | Override persistent savings file location. |
| `HEADROOM_TOIN_PATH` | derived from `${HEADROOM_WORKSPACE_DIR}` | Override TOIN telemetry file location. |
| `HEADROOM_SUBSCRIPTION_STATE_PATH` | derived from `${HEADROOM_WORKSPACE_DIR}` | Override subscription tracker state file. |
| `HEADROOM_PERIODIC_TOIN_STATS` | `true` | Controls periodic TOIN stats logging in long-lived proxy workers. |
| `HEADROOM_MEMORY_INJECTION_MODE` | `live_zone_tail` | Memory-context routing mode: `live_zone_tail` (default), `disabled`, or `tool` (auto-injection off; the agent calls memory tools explicitly). |
| `HEADROOM_PROXY_PYTHON_FORWARDER_MODE` | `byte_faithful` | Preserve unchanged request bytes. Use `legacy_json_kwarg` only for a deliberate rollback. |
| `HEADROOM_STRIP_INTERNAL_HEADERS` | `enabled` | Remove internal Headroom request headers before forwarding. |
| `HEADROOM_PROXY_STRIP_INTERNAL_HEADERS` | `enabled` | Rust proxy: same policy as `HEADROOM_STRIP_INTERNAL_HEADERS` but for the Rust transparent proxy. |
| `HEADROOM_EMBEDDER_RUNTIME` | default embedder selection | Set to `pytorch_mps` to run the memory embedder via the torch sentence-transformers backend on the Apple GPU (MPS). |
| `HEADROOM_KOMPRESS_BACKEND` | `auto` | Select ONNX or PyTorch compression inference. Auto tries ONNX CPU first. |
| `ORT_DYLIB_PATH` | auto-pinned | Path to the ONNX Runtime shared library loaded by the Rust core (magika detection, fastembed embeddings), which loads ORT dynamically on every platform. |
| `HEADROOM_MAGIKA_INIT_TIMEOUT_SECS` | `5` | Upper bound (integer seconds, > 0) on magika's one-time ONNX session init in the Rust detection chain. |
| `HEADROOM_BETA_HEADER_STICKY` | `enabled` | Keep previously sent beta tokens stable within a session. |
| `HEADROOM_BETA_TRACKER_MAX_SESSIONS` | `1000` | LRU capacity of the in-memory session beta tracker. |
| `HEADROOM_PROXY_BETA_HEADER_STICKY` | `enabled` | Rust proxy: same per-conversation beta-token union as `HEADROOM_BETA_HEADER_STICKY`, applied to `anthropic-beta` / `openai-beta` on the intercepted `/v1/messages`, `/v1/chat/completions`, and `/v1/responses` routes. |
| `HEADROOM_LIVE_ZONE_DISABLE_ARMS` | -- | Rust proxy live-zone dispatcher: comma-separated content types whose compression arm is forced to a no-op, e.g. `source_code,plain_text`. |
| `HEADROOM_MODEL_ROUTER_ENABLED` | `off` | Enable cost-aware model routing. `1`/`true`/`yes`/`on`/`enabled` turns it on and requires `HEADROOM_MODEL_ROUTES`. |
| `HEADROOM_MODEL_ROUTES` | -- | JSON array of ordered routing rules for cost-aware model routing (schema below). |
| `HEADROOM_THINKING_COMPACT` | `off` | Compact plain-text reasoning that models re-send every turn (Kimi/GLM/DeepSeek `reasoning_content` / inline `<think>`): Kompress it on warm turns, drop it on cold turns. |
| `HEADROOM_THINKING_COMPACT_KEEP_LAST` | `1` | Most-recent assistant turns whose reasoning is left intact (the active reasoning the model still uses). |
| `HEADROOM_COLD_RECOMPACT` | `off` | On a confirmed-cold turn (idle past the real cache TTL), recompact the whole prefix , cross-turn dedupe + superseded-read drop + lossless folds , instead of forwarding a byte-identical prefix to a dead cache. |
| `HEADROOM_PREFIX_STATE_FILE` | -- | Path where the proxy saves its prefix-cache trackers on a graceful shutdown and restores them on the next start (then deletes the file), so warm conversations replay the exact prefix the provider cached instead of re-writing it. |
| `HEADROOM_DEDUPE` | `off` base; on in coding profile | Whole-conversation verbatim cross-turn dedup in the router (cache-safe, information-preserving via retrieval markers). |
| `HEADROOM_CACHE_TTL_LEARN` | `off` | Append per-turn cache-outcome observations (provider, model, idle, hit/miss) to `cache_ttl_observations.jsonl` for the offline `headroom-cache-ttl` learner. |
| `HEADROOM_KOMPRESS_ENDPOINT` / `HEADROOM_KOMPRESS_ENDPOINT_TOKEN` | -- | Offload ML compression (Kompress) to a remote endpoint instead of the local ONNX model , used by reasoning compaction and the router when set. |
| `HEADROOM_1M_MODEL` | `claude-opus-5` | Fallback model that `headroom wrap claude --1m` targets when neither `--model` nor `ANTHROPIC_MODEL` is set. |

Source: [docs/content/docs/proxy.mdx](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/docs/content/docs/proxy.mdx).

| Setting | Documented default | Purpose |
|---|---|---|
| `HEADROOM_COMPRESS_PASSTHROUGH` | `0` | Also compress custom proxy paths that fall through to the catch-all handler (OpenAI Responses-shaped bodies, path ends in `/responses`). |
| `HEADROOM_MIN_TOKENS` | `500` base; `10` in coding profile | Minimum block size before a tool output is compressed. |
| `HEADROOM_COMPRESS_USER_MESSAGES` | profile | Compress text inside user-role messages. |
| `HEADROOM_COMPRESS_SYSTEM_MESSAGES` | unset | Compress system prompts. |
| `HEADROOM_PROTECT_RECENT` | profile | Positional protection window; the current coding profile uses zero and protects reads by type. |
| `HEADROOM_FORCE_KOMPRESS_ALL` | `false` | Route *all* content through Kompress, bypassing per-type selection. |
| `HEADROOM_TOOL_SEARCH` | On in coding profile | Defer tool schemas behind proxy-managed search. |
| `ENABLE_TOOL_SEARCH` | client (Claude Code) | Keep Claude Code's own deferred tool-loading active behind a custom base URL ([issue #746](https://github.com/headroomlabs-ai/headroom/issues/746)). |
| `HEADROOM_LOG_PAYLOAD_PREVIEW` | `off` | Log up to 4 KB of retrieved content. This can expose source or secrets. |
| `HEADROOM_LOG_LEVEL` | `warning` | uvicorn's log level (`critical`, `error`, `warning`, `info`, `debug`, `trace`). |
| `HEADROOM_OTEL_METRICS_ENABLED` | `false` | Export OpenTelemetry metrics (`HEADROOM_OTEL_METRICS_ENDPOINT`, …). |
| `HEADROOM_LANGFUSE_ENABLED` | `false` | Emit Langfuse traces (`LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY`). |
| `HEADROOM_PROXY_TOKEN` | none | Require a token from non-loopback callers, as `X-Headroom-Proxy-Token: <token>` or `Authorization: Bearer <token>`. |
| `HEADROOM_ALLOW_UNAUTHENTICATED_BIND` | `false` | Acknowledge a non-loopback bind (`--host 0.0.0.0`, `::`, a LAN address) with **no** `HEADROOM_PROXY_TOKEN`. |
| `HEADROOM_COMPRESS_ALLOW_REMOTE` | `false` | Allow non-loopback callers to reach `POST /v1/compress` and `POST /v1/usage`. |
| `HEADROOM_OFFLINE` | `false` | Block Headroom-initiated external connections; keep forwarding client requests. |
| `HEADROOM_LICENSE` | unset | Licence token, read by core and every licensed extension. `HEADROOM_LICENSE_KEY` is a deprecated alias for one release and logs a warning. |
| `HEADROOM_USAGE_REPORTING` | `false` | Set `1` to let the proxy validate the licence and post aggregate usage counts (no content) to the Headroom cloud. |
| `HEADROOM_TLS_STRICT` | strict | Set `0` to relax CA-constraint checks behind a corporate TLS-inspection proxy. |
| `HEADROOM_CERT_STORE` | `system,bundled` | Trusted roots for upstream TLS: OS certificate store and/or certifi. |
| `HEADROOM_CA_BUNDLE` | unset | Extra PEM roots (e.g. a Zscaler root) added to the trusted set. |
| `--embedding-server` / `HEADROOM_EMBEDDING_SERVER` | off | Share one ONNX embedder across workers (~600 MB RSS saved). |

## SDK-only settings

`HeadroomClient(default_mode=...)`, per-call `headroom_mode`, `headroom_output_buffer_tokens`, and `headroom_keep_turns` belong to SDK calls. The TypeScript client has `baseUrl`, `apiKey`, `timeout`, `fallback`, and `retries`. `HEADROOM_BASE_URL` and `HEADROOM_API_KEY` configure that client. They do not replace proxy authentication through `HEADROOM_PROXY_TOKEN`.

Python transform objects such as `SmartCrusherConfig` and `CacheAlignerConfig` are library configuration. A field on these classes is not automatically a proxy flag. Removed classes `RollingWindowConfig`, `IntelligentContextConfig`, and `ScoringWeights` are not current configuration choices.

## Source links

- [headroom/cli/proxy.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cli/proxy.py)
- [headroom/cli/wrap.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cli/wrap.py)
- [headroom/cli/install.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cli/install.py)
- [headroom/proxy/server.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/proxy/server.py)
- [headroom/providers/codex/runtime.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/providers/codex/runtime.py)
- [headroom/context_tool_cleanup.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/context_tool_cleanup.py)
- [headroom/settings_store.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/settings_store.py)
- [headroom/rollout.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/rollout.py)
- [headroom/offline.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/offline.py)
- [headroom/update_check.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/update_check.py)
- [headroom/telemetry/beacon.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/telemetry/beacon.py)
- [docs/content/docs/proxy.mdx](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/docs/content/docs/proxy.mdx)
- [docs/content/docs/configuration.mdx](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/docs/content/docs/configuration.mdx)
- [docs/content/docs/security-model.mdx](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/docs/content/docs/security-model.mdx)
- [docs/content/docs/filesystem-contract.mdx](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/docs/content/docs/filesystem-contract.mdx)
- [docs/content/docs/persistent-installs.mdx](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/docs/content/docs/persistent-installs.mdx)
- [docs/content/docs/runtime-rollouts.mdx](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/docs/content/docs/runtime-rollouts.mdx)

No live proxy, subscription login, model behavior, or file restoration was tested. Wrapper defaults can modify local agent configuration; plaintext originals and optional learned memory need the same care as source files.

## Compression settings

| Setting | Effective default | What changes | Recommendation |
|---|---|---|---|
| `HEADROOM_SAVINGS_PROFILE` | `coding` | Seeds a group of compression settings. `balanced` pins keep-ratio 0.30, protects 4 recent messages, and uses token mode. `agent-90` pins 0.10, enables user/system compression, and forces Kompress. `general` targets prose-oriented workloads. Nominal savings percentages are display targets. | Keep `coding`. Avoid `agent-90` for edits and reviews. |
| `--mode` / `HEADROOM_MODE` | `cache` | `cache` compresses the fresh delta and replays the prior forwarded prefix. `token` permits more history compression. Old aliases remain accepted. | Keep `cache`. Measure provider cache usage as well as token counts. |
| `--lossless` / `HEADROOM_LOSSLESS` | `false` | Uses format-native lossless compaction, forces SmartCrusher marker-free behavior, and disables injected retrieval tools/markers. Representation can change even though the original information remains recoverable. | Turn on for the first trial. Later compare normal CCR mode. |
| `--no-optimize` | Off | Turns off compression. It does not remove every proxy behavior, such as configured routing. | Use as a proxy-through baseline. |
| `HEADROOM_LOSSLESS_COMPACTION` | `1` | Controls byte-reversible folds such as repeated-log collapse and search heading compaction. Read per request. | Keep on. |
| `HEADROOM_SMART_CRUSHER_COMPACTION` | `1` in coding | Tries compact JSON/table encoding before scored row retention. | Keep on. |
| `HEADROOM_COMPACTION_FORMAT` | `csv-schema` | Lossless SmartCrusher renderer. Valid choices are `csv-schema`, `json`, `markdown-kv`. | Keep default initially. Compare `markdown-kv` only if table interpretation proves poor. |
| `--target-ratio` / `HEADROOM_TARGET_RATIO` | Unset | Fraction of tokens Kompress should retain. 0.5 means keep about half. It is neither a total-session saving guarantee nor the JSON row-retention limit. | Leave adaptive. |
| `HEADROOM_MIN_TOKENS` | `10` in coding | Minimum eligible message size at the router/pipeline level. Bare `ProxyConfig` uses 500. SmartCrusher also has its own 200-token threshold. | Keep profile default while measuring. Do not mistake it for the inner JSON threshold. |
| `HEADROOM_MIN_CHARS_FOR_BLOCK` | `25` in coding | Minimum content-block length for compression. Bare router default is 500 characters. | Keep default. |
| `HEADROOM_MAX_ITEMS` | `15` in coding | Target retained rows for SmartCrusher when its lossy row-selection path runs. Required/error/outlier rows can exceed the target. | Keep default. It is not an absolute cap. |
| `HEADROOM_COMPRESS_USER_MESSAGES` | `1` in coding | Allows user-role observations/text to enter compression. User-role Anthropic `tool_result` blocks have separate handling. On the cache replay path, the opening task and newest actual user prompt stay protected. Text-based agents can label tool observations as user strings. | Keep coding default for a useful trial. Set `0` only if protecting all pasted user text matters more than compression of user-role observations. |
| `HEADROOM_COMPRESS_SYSTEM_MESSAGES` | `0` in coding | Allows system/developer instruction compression when enabled. Cache mode also protects its already-forwarded prefix. | Keep `0`. |
| `HEADROOM_PROTECT_RECENT` | `0` in coding | Positional protection window. Four recent messages is an SDK/general default, not the coding proxy default. Coding uses type-specific read protection so fresh test/log outputs still compress. | Keep profile default. Do not increase just to protect source reads. |
| `HEADROOM_PROTECT_ANALYSIS_CONTEXT` | `1` | Protects code that is the subject of review/debug/analysis. | Keep on. |
| `HEADROOM_PROTECT_READS` | `1` in coding | Detects shell file-read commands as well as direct read tools and preserves their exact bytes. | Keep on. This matters for precise patches. |
| `HEADROOM_EXCLUDE_TOOLS` | Built-in set plus additions | Adds tools excluded from lossy compression. Supports case-insensitive names, aliases, and globs. Excluded results can still receive lossless folds or deduplication. | Keep built-ins. Add sensitive/custom tools only when needed. |
| `--protect-tool-results` / `HEADROOM_PROTECT_TOOL_RESULTS` | Empty | Adds lossy exclusions and restores indefinite age protection for all excluded tool results, including Read/Glob/Grep. It does not promise every output is byte-identical. | Leave empty first. Protect a specific tool when a quality failure identifies it. |
| `HEADROOM_DEDUPE` | `1` in coding | Replaces repeated tool-result spans with pointers to earlier retained content. It operates in both lossless and CCR modes when the client can resolve that representation. | Keep on. Check readability and retry counts. |
| `HEADROOM_LOSSLESS_THEN_LOSSY` | `1` in coding | After an information-preserving fold, tries ML compression on the remainder. Inert in lossless mode. Diffs are not lossy-chained. | Keep profile value during a CCR trial. `--lossless` disables this path for the baseline. |
| `HEADROOM_LOSSY_MIN_EXTRA_SAVINGS` | `0.05` | Minimum additional saving needed to replace a lossless fold with the lossy result. | Keep default. Lowering it buys small token savings at greater evidence-loss risk. |
| `--code-aware` / `--no-code-aware`, `HEADROOM_CODE_AWARE_ENABLED` | On in executable coding proxy | AST-based code compression for eligible content. Direct `ContentRouterConfig` defaults off. Read/analysis protections still apply. | Keep protections. Use `--no-code-aware` for a trial if source navigation is the main workload. |
| `HEADROOM_PREFER_CODE_AWARE_FOR_CODE` | `true` | Prefers AST compression over generic ML for detected source. | Keep default. |
| `--disable-kompress` / `HEADROOM_DISABLE_KOMPRESS` | Off | Disables the regular ML text compressor. Some fallback behavior has a separate switch. | Prefer `--lossless` for a complete no-lossy trial. |
| `--disable-kompress-fallback` / `HEADROOM_DISABLE_KOMPRESS_FALLBACK` | Off | With Kompress disabled, sends unmatched content through unchanged instead of the historical fallback. | Set with `--disable-kompress` if the goal is no ML text compression. |
| `--disable-kompress-anthropic` / `HEADROOM_DISABLE_KOMPRESS_ANTHROPIC` | Unset | Overrides the global Kompress toggle for Anthropic traffic. | Leave unset unless isolating a provider-specific problem. |
| `--disable-kompress-openai` / `HEADROOM_DISABLE_KOMPRESS_OPENAI` | Unset | Same override for OpenAI traffic. | Leave unset. |
| `HEADROOM_FORCE_KOMPRESS_ALL` | Off | Bypasses content-specific compressor choice for eligible content. Tool exclusions and recoverability gates remain. | Keep off. |
| `HEADROOM_FORCE_KOMPRESS` | Off in coding | Separate profile pipeline control that forces Kompress at request time. | Keep off. Do not confuse with `FORCE_KOMPRESS_ALL`. |
| `--compressor` / `HEADROOM_COMPRESSORS` | All default built-ins | Narrows enabled built-in compressors to the selected names. Valid built-ins are `smart_crusher`, `kompress`, `code_aware`, `search`, `log`, `tabular`, `config`, `html`, `image`. `*` also activates discovered external compressors. Diff and dense-line settings are not a complete independent selector here. | Keep default. Selection is useful to isolate a problem. Avoid `*` if plugins exist. |
| `HEADROOM_LOSSLESS_ONLY` | Unset | Forces SmartCrusher lossless-only, marker-free behavior. It does not convert every other compressor to lossless mode. | Use `HEADROOM_LOSSLESS=1` for the whole pipeline. |
| `HEADROOM_EXPERIMENTAL_READ_KEEP_RATIO` | Unset/0 | Deliberately runs lossy Kompress on protected source reads at a selected keep ratio. | Keep off. |
| `--read-maturation` | Off | Experimental release of inactive reads after a quiet interval. Requires the allowed rollout channel. | Keep off. |
| `HEADROOM_READ_MATURATION_QUIESCE_TURNS` | 5 | Quiet turns before a read can mature, when maturation is enabled. | Leave unchanged while the feature is off. |
| `HEADROOM_READ_MATURATION_MAX_HOLD_TURNS` | 25 | Upper bound on how long maturation retains the read. | Leave unchanged. |
| `HEADROOM_READ_MATURATION_MIN_SIZE_BYTES` | 2048 | Only larger reads enter maturation. | Leave unchanged. |
| `--no-read-lifecycle` | Off, lifecycle on | Disables file read staleness/supersession tracking. It differs from experimental maturation. | Keep default unless a stale-read failure is observed. |

Sources: [actual proxy construction](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/proxy/server.py#L1019), [router](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/content_router.py), [built-in exclusions](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/config.py), [SmartCrusher implementation](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/smart_crusher.py).

## CCR and the different caches

| Setting | Default | Meaning | Recommendation |
|---|---|---|---|
| `--no-ccr` / `HEADROOM_NO_CCR` | Off | Disables retrieval markers, injected retrieval tool, and server-side response handling together. It is not the same as lossless mode. | Set `1` with lossless mode for the current baseline. Enable CCR and retrieval together when trying lossy compression. |
| `HEADROOM_CCR_TTL_SECONDS` | 1800 seconds | Retrieval-store lifetime for originals. Expiry can make an old marker unresolvable. | Set 3600 seconds for the requested one-hour retention. This applies when CCR is enabled. |
| `HEADROOM_CCR_BACKEND` | SQLite locally | Stores originals. `memory` avoids disk persistence but loses data on restart. Redis can support shared deployments. | SQLite for recoverability across restart; memory only if disk copies are unacceptable. |
| `--ccr-inline-resolve` / `HEADROOM_CCR_INLINE_RESOLVE` | Off | Resolves response-side markers for clients without a tool-call round trip. Non-streaming only. | Keep off for coding agents with retrieval tools. |
| `--no-ccr-proactive-expansion` / `HEADROOM_NO_CCR_PROACTIVE_EXPANSION` | Off | Disables automatic expansions based on tracked context. | Keep default during a CCR trial. Count expansions as overhead. |
| Flat `ProxyConfig.ccr_max_retrieval_rounds` | 3 | Caps server-handled retrieval rounds. | Keep default. No verified equivalent general CLI/env setting. |
| Flat `ProxyConfig.ccr_max_proactive_expansions` | 2 | Caps proactive expansions. | Keep default. |
| `--no-cache` | Off | Disables local full-response replay cache. This is separate from provider prompt caching and CCR. | Disable for a clean comparison. Tool-agent streaming traffic often cannot use it anyway. |
| Flat `ProxyConfig.cache_ttl_seconds` | 3600 seconds | Lifetime of full-response cache entries. | No need to tune for this trial. |
| Flat `ProxyConfig.cache_max_entries` | 1000 | Full-response LRU capacity. | Leave unchanged. |
| Flat `ProxyConfig.prefix_freeze_enabled` | true | Controls tracking of the already-forwarded cached prefix. | Keep on. |
| Flat `ProxyConfig.prefix_freeze_session_ttl` | 600 seconds | Tracker cleanup TTL. Provider cache lifetime plus safety margin can extend actual retention. | Leave unchanged. |
| `HEADROOM_PREFIX_STATE_FILE` | Unset | Saves prefix tracker content on graceful shutdown, then restores valid entries. Contains conversation content. Single worker only; stateless mode disables it. | Leave unset initially. |
| `HEADROOM_COMPRESSION_CACHE_MB` | 64 MB | Memory budget for compressed-result reuse. Different from full-response caching or CCR originals. Proxy backs it with a disk result store. | Keep default. |
| `HEADROOM_COLD_RECOMPACT` | Off | Recompacts a confirmed-cold prefix after provider cache expiry. | Keep off for a first trial. |
| `HEADROOM_CACHE_TTL_LEARN` | Off | Writes bounded local cache hit/idle observations for an offline TTL estimator. | Optional when measuring cache issues. It changes observation, not compression. |
| `HEADROOM_THINKING_COMPACT` | Off | Compresses resent plain reasoning for certain other providers. No effect on Claude/Codex encrypted reasoning. | Keep off for this setup. |
| `HEADROOM_THINKING_COMPACT_KEEP_LAST` | 1 | Protects recent plain-reasoning assistant turns when that feature is on. | Leave unchanged. |
| `HEADROOM_BETA_HEADER_STICKY` | `enabled` | Retains seen beta tokens for the conversation to avoid prefix churn. A removed client flag can therefore remain active. | Keep default unless explicitly retiring a beta within the same conversation. |
| `HEADROOM_BETA_TRACKER_MAX_SESSIONS` | 1000 | LRU session capacity for beta token tracking. | Leave unchanged. |

The full-response cache is named `SemanticCache`, but the proxy implementation hashes the request. It does not perform fuzzy semantic matching. It partitions entries by credentials/principal and uses non-streaming paths. Provider prompt caching reuses computation at Anthropic/OpenAI. CCR stores original compressed inputs. The compressed-result cache prevents repeated local compression. These four systems have different purposes and lifetimes.

Sources: [CCR store](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cache/compression_store.py), [flat proxy config](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/proxy/models.py), [response cache](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/proxy/semantic_cache.py), [prefix tracker](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/cache/prefix_tracker.py), [configuration docs source](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/docs/content/docs/configuration.mdx).

## Local ML and latency controls

| Setting | Default | Meaning and recommendation |
|---|---|---|
| `HEADROOM_KOMPRESS_BACKEND` | `auto` | Chooses ONNX CPU with PyTorch fallback. Explicit alternatives include `onnx_cpu`, `onnx_coreml`, `pytorch`, `pytorch_mps`. Keep auto. Benchmark Apple GPU startup and end-to-end latency before changing. |
| `HEADROOM_KOMPRESS_ENDPOINT` plus `_TOKEN` | Unset | Sends ML compression content to a remote service. Keep unset for local processing. |
| `HEADROOM_KOMPRESS_MAX_TOKENS` | 50000 | Input-size ceiling before the router uses a cheaper fallback. Zero disables the ceiling. Keep default. |
| `HEADROOM_TEXT_CRUSHER` | Off | Enables the extractive TextCrusher fallback for inputs above the ML size ceiling. Keep off for baseline; test separately on long prose. |
| `HEADROOM_COMPRESSION_TIMEOUT_SECONDS` | 30 | Outer compression-stage timeout. Keep default until measurement identifies a stall. |
| `HEADROOM_COMPRESSION_DEADLINE_MS` | 20000 | Softer in-router deadline for ML work. Keep default. |
| `HEADROOM_ML_STAGE_DEADLINE_SECONDS` | 15, clamped against outer timeout | Stops starting more ML work after the stage budget. Zero disables it. Keep enabled. |
| `HEADROOM_COMPRESS_WORKERS` | 4 | Router's per-message compression workers. It is not the same as proxy process workers or `--compression-max-workers`. Keep default. |
| `HEADROOM_DETECT_BACKEND` | Automatic | Forces Rust/Python content detection when set. Keep automatic. |
| `HEADROOM_FREEZE_BLOCK_DECISION` | Off | Experimental stable per-block compress/skip verdict. Keep off initially. |
| `HEADROOM_NET_COST_POLICY` | Off | Optional provider-cache cost gate for mutations. It is separate from cache mode. Keep off until a measured cache issue justifies it. |
| `HEADROOM_NET_COST_EXPECTED_READS` | 10 | Estimated future prompt-cache reuse for that gate. Do not tune without real traffic. |
| `HEADROOM_NET_COST_P_ALIVE` | 1.0 | Estimated probability provider cache survives. Do not tune without evidence. |

Sources: [router controls and safety budgets](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/content_router.py), [Kompress backend](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/kompress_compressor.py).

## SDK and direct-compressor appendix

These are Python fields or direct constructor arguments. They are not automatically proxy environment settings. The proxy builds its own `ContentRouterConfig` and forwards only specific controls. Putting nested `smart_crusher`, `cache_aligner`, or SDK context settings in `HEADROOM_PROXY_CONFIG_JSON` does not make them work. That variable accepts flat `ProxyConfig` fields at the worker/factory loading path. The ordinary Click entry point constructs its config itself.

### One-function `CompressConfig`

| Field | SDK default | Meaning | Recommendation for custom code |
|---|---|---|---|
| `compress_user_messages` | false | Allows user message compression. | False for task instructions. |
| `compress_system_messages` | true | Allows system compression. Unlike coding proxy default. | Set false for instruction fidelity. |
| `protect_recent` | 4 | Protects recent messages. | Keep unless a controlled tool-output-only workflow. |
| `protect_analysis_context` | true | Protects code needed for analysis. | Keep. |
| `frozen_message_count` | 0 | Number of prefix messages caller declares immutable. | Set from actual replay state. |
| `target_ratio` | None | Kompress token keep fraction. | Leave adaptive. |
| `min_tokens_to_compress` | 250 | Minimum eligible message size. | Keep until measured. |
| `kompress_model` | None | Optional model/behavior override. | Leave default. |
| `savings_profile` | None | Applies named profile to this config. | Explicitly choose if needed; do not assume proxy defaults. |
| `diagnostics` | false | Adds per-message decisions. | Turn on in a trial. |
| `mode` | None | `agent` selects a verified lossless workflow. This is not proxy `cache`/`token`. | Consider `agent` for direct agent preprocessing. |
| `verify_lossless` | false | Checks reversibility and returns source on failed verification. Forced by agent mode. | True for a direct lossless integration. |

Source: [compress.py](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/compress.py).

### SmartCrusher direct settings

| Field | Default | Meaning and recommendation |
|---|---|---|
| `enabled` | true | Enables JSON compression. Keep. |
| `min_items_to_analyze` | 5 | Skips short arrays. Keep. |
| `min_tokens_to_crush` | 200 | Skips small arrays. Keep. |
| `max_items_after_crush` | 15 | Lossy row-retention target. Keep unless all rows matter, then use lossless mode. |
| `variance_threshold` | 2.0 | Outlier cutoff in standard deviations. Lower retains more anomalies. Keep. |
| `uniqueness_threshold` | 0.1 | Grouping/uniqueness heuristic. Keep. |
| `similarity_threshold` | 0.8 | Similarity grouping heuristic. Keep. |
| `preserve_change_points` | true | Retains detected distribution changes. Keep. |
| `factor_out_constants` | false | Factors repeated values. Leave. |
| `include_summaries` | false | Adds statistical summaries. Leave. |
| `use_feedback_hints` | true | Uses learned retention hints. Keep for normal trials. |
| `toin_confidence_threshold` | 0.5 in transform class | Confidence needed for learned hints. `headroom.config.SmartCrusherConfig` instead says 0.3. Keep the actual transform default. |
| `dedup_identical_items` | true | Removes redundant rows. Keep. |
| `first_fraction`, `last_fraction` | 0.30, 0.15 | Positional retention allocation. Keep unless order carries a known special meaning. |
| `lossless_min_savings_ratio` | 0.15 | Minimum byte saving for a lossless table fold. Docs and stale comments say 0.30. Actual config is 0.15. Keep. |
| `lossless_only` | false | Prevents lossy row drops and opaque-cell offload markers. Use true when every row matters. |
| `compaction_core_field_fraction` | 0.8 | Fraction of rows containing a key before it counts as core. Leave. |
| `compaction_heterogeneous_core_ratio` | 0.6 | Threshold before bucketing heterogeneous rows. Leave. |
| `compaction_max_flatten_inner_keys` | 6 | Nested-column flattening bound. Leave. |
| `compaction_min_buckets`, `compaction_max_buckets` | 2, 8 | Useful discriminator-bucket count range. Leave. |
| `audit_safe` | false | Adds explicit protection for rows matching caller patterns. No proxy constructor wiring found. Use only in a direct integration that needs it. |
| `protected_patterns` | None | Literal/regex patterns defining protected rows. Must be supplied for audit-safe protection to matter. |
| `fail_closed_on_protected_loss` | true | Returns original if protection verification fails. Keep. |
| Constructor `with_compaction` | true | Enables lossless-first encoding. Keep. |
| Constructor `compaction_format` | None, env/default renderer applies | Chooses compact table representation. Keep default. |

`headroom.config` also exposes nested relevance and anchor fields, but the transform's current Rust config bridge hardcodes `relevance_threshold=0.3` and does not forward those nested objects. Do not present their values as working SmartCrusher proxy knobs.

Sources: [transform config and Rust bridge](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/smart_crusher.py), [general SDK config](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/config.py).

### Search, log, diff, text, and code direct settings

None of the individual fields below has general proxy CLI/env plumbing in the construction inspected. The proxy uses the classes' defaults plus global CCR flags and search grouping. `ContentRouterConfig` can accept a custom compressor config in a custom Python pipeline.

| Class and fields | Defaults | Meaning and recommendation |
|---|---|---|
| `SearchCompressorConfig.max_total_matches`, `max_matches_per_file`, `max_files` | 30, 5, 15 | Limits result selection across files. Keep initially; use lossless when exhaustive search results matter. |
| Search `always_keep_first`, `always_keep_last` | true, true | Keeps boundary matches. Keep. |
| Search `context_keywords`, `boost_errors` | [], true | Extra query terms and error preference. Only add known task terms. |
| Search `enable_ccr`, `min_matches_for_ccr`, `group_by_file` | true, 10, false | Retrieval storage and grouped output. Proxy enforces its global CCR and mode grouping decisions. |
| `LogCompressorConfig.max_errors`, `error_context_lines` | 10, 3 | Error selection and nearby lines. These caps mean error preservation claims are conditional. Leave for trial; retrieve original before acting on a precise failure. |
| Log `keep_first_error`, `keep_last_error` | true, true | Preserves boundary failures. Keep. |
| Log `max_stack_traces`, `stack_trace_max_lines` | 3, 20 | Trace count/length caps. Keep until real stack evidence requires more. |
| Log `max_warnings`, `dedupe_warnings` | 5, true | Warning cap/dedup. Keep. |
| Log `keep_summary_lines`, `max_total_lines` | true, 100 | Retains final summaries and bounds log size. Keep. |
| Log `collapse_runtime_frames`, `trace_head_frames`, `trace_app_frames` | true, 3, 5 | Prioritizes application frames over runtime boilerplate. Keep. |
| Log `enable_ccr`, `min_lines_for_ccr` | true, 50 | Retrieval storage behavior. Keep with lossy compression. |
| `DiffCompressorConfig.max_context_lines`, `max_hunks_per_file`, `max_files` | 2, 10, 20 | Bounds diff display. Avoid aggressive compression for code review. |
| Diff `always_keep_additions`, `always_keep_deletions` | true, true | Preserves changed lines within retained material. Keep. |
| Diff `enable_ccr`, `min_lines_for_ccr` | true, 50 | Retrieval behavior. Keep. |
| `TextCrusherConfig.target_ratio` | 0.5 | Fraction of prose retained through sentence selection. Leave unless quality tested. |
| Text `w_recency`, `w_relevance`, `w_salience` | 1.0, 2.0, 1.5 | Weights for sentence selection. Leave. |
| Text `min_segment_chars`, `near_dup_threshold`, `min_segments_for_crush` | 12, 0.85, 6 | Segmentation and dedup controls. Leave. |
| `CodeCompressorConfig.preserve_imports`, `preserve_signatures`, `preserve_type_annotations`, `preserve_decorators` | All true | Preserves source interface details. Keep all true. |
| Code `docstring_mode` | `FIRST_LINE` | Keeps a short docstring form. Full docs may matter for APIs. |
| Code `target_compression_rate` | 0.2 | AST compressor target. Separate from Kompress target-ratio. Do not tune on live editing without tests. |
| Code `max_body_lines`, `compress_comments` | 5, true | Body/comment reduction. Avoid for code currently being edited. |
| Code `min_tokens_for_compression`, `language_hint` | 100, None | Minimum size and parser override. Keep automatic detection. |
| Code `fallback_to_kompress`, `semantic_analysis` | true, true | ML fallback for unsupported source and semantic selection. Prefer passthrough to generic ML for exact edits. |
| Code `enable_ccr`, `ccr_ttl` | true, 300 seconds | Direct code-compressor retrieval behavior. This 5-minute field differs from global CCR store TTL. Leave untouched for proxy use. |
| `KompressConfig.device`, `model_id` | `auto`, shared HF default | Local model placement and weights. Leave auto/default. |
| Kompress `enable_ccr`, `chunk_words`, `score_threshold`, `min_input_words` | true, 350, 0.5, 64 | Retrieval, chunking, and learned token cutoff. Keep defaults unless evaluating text compression itself. |

Sources: [search](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/search_compressor.py), [logs](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/log_compressor.py), [diff](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/diff_compressor.py), [text](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/text_crusher.py), [code](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/code_compressor.py), [Kompress](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/kompress_compressor.py).

### SDK cache/context fields and misleading documentation

| Field/group | Default | Actual applicability and recommendation |
|---|---|---|
| `HeadroomConfig.default_mode` | `audit` | SDK audit/optimize/simulate axis. Not proxy cache/token. Use audit first in an SDK integration. |
| `HeadroomConfig.output_buffer_tokens` | 4000 | SDK output budget reservation. Not a proxy option. |
| Per-call `headroom_output_buffer_tokens` | Uses config | Passed as output budget to SDK pipeline. It does not set the provider generation cap. |
| Per-call `headroom_keep_turns` | None | Accepted by SDK client but not used in its inspected pipeline call. Do not promise it preserves/compresses a selected number of turns. |
| Header `x-headroom-keep-last-turns` | Unset | Different proxy option. Actually drops older messages before optimization. Avoid for this workflow. |
| `HeadroomConfig.model_context_limits` | Empty overrides | SDK model budget overrides. Does not increase provider context entitlement. |
| `HeadroomConfig.store_url`, `generate_diff_artifact` | `sqlite:///headroom.db`, false | SDK metrics/storage and diff artifact controls. Not CLI proxy deployment fields. |
| `CacheAlignerConfig.enabled` | false | Opt-in detector-only SDK transform. Proxy hard-disables it. Keep off unless debugging prefix drift. |
| CacheAligner `use_dynamic_detector`, `detection_tiers`, `extra_dynamic_labels`, `entropy_threshold`, `date_patterns` | true, regex, [], 0.7, built-in date patterns | Retained configuration fields, but current `apply()` calls its fixed `detect_volatile_content` function rather than wiring this old detector configuration. Do not promise custom regexes change proxy behavior. |
| CacheAligner `normalize_whitespace`, `collapse_blank_lines`, `dynamic_tail_separator` | true, true, built-in separator | Historical fields. Current transform explicitly never moves or rewrites content. They do not repair prompts. |
| `CacheOptimizerConfig.enabled`, `auto_detect_provider`, `min_cacheable_tokens` | true, true, 1024 | SDK provider-cache helper. Separate from proxy prefix tracking. Keep defaults in custom SDK use. |
| SDK cache `enable_semantic_cache`, `semantic_cache_similarity`, `semantic_cache_max_entries`, `semantic_cache_ttl_seconds` | false, 0.95, 1000, 300 | Optional SDK response semantic-cache layer. Different from proxy hash cache. Leave off for coding tasks. |
| `CCRConfig.enabled`, `inject_retrieval_marker`, `inject_tool` | true, true, true | SDK CCR controls. Proxy supplies its own limited instance and flat fields. Keep enabled with lossy compression. |
| CCR `store_max_entries`, `store_ttl_seconds`, `min_items_to_cache` | 1000, 1800, 20 | SDK declaration values. For actual proxy store retention, use verified global backend/TTL controls. Do not assume a nested CCR config reaches it. |
| CCR `feedback_enabled`, `inject_system_instructions`, `marker_template` | true, false, built-in | Feedback and presentation controls. No generic proxy env mapping verified. |
| `PrefixFreezeConfig.enabled`, `min_cached_tokens`, `session_ttl_seconds`, `force_compress_threshold` | true, 1024, 600, 0.5 | SDK/tracker settings. Proxy exposes only selected flat fields. Keep freeze enabled; no user tuning needed. |
| `ReadLifecycleConfig.enabled`, `compress_stale`, `compress_superseded`, `min_size_bytes` | true, true, false, 512 | Custom-router lifecycle controls. Proxy passes only enabled from its lifecycle flag. Keep defaults. |
| `ReadMaturationConfig.enabled`, `quiesce_turns`, `max_hold_turns`, `min_size_bytes` | false, 5, 25, 2048 | Experimental read release. Keep disabled. |
| `CompressionProfile.bias`, `min_k`, `max_k` | 1.0, 3, None | Custom per-tool compression preference. Proxy supports `HEADROOM_TOOL_PROFILES` presets, not arbitrary constructor objects in a plain env string. Leave presets untouched initially. |

The SDK no longer has `RollingWindowConfig`, `IntelligentContextConfig`, or `ScoringWeights`. Do not install a history-dropping policy based on old examples. `headroom_keep_turns` and the proxy keep-last-turns header are especially easy to confuse.

Sources: [SDK config](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/config.py), [client actual pipeline call](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/client.py#L450), [detector-only CacheAligner](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/transforms/cache_aligner.py#L296), [proxy keep-last-turns handling](https://github.com/headroomlabs-ai/headroom/blob/f10725e6b9940d8bc2fcde950c86f8ac97543cb6/headroom/proxy/handlers/anthropic.py#L1700).

## Remaining source caveats

- Generic docs say dedupe is off; executable coding profile turns it on.
- The bare ProxyConfig mode is token, while executable default is cache.
- Some CLI code-aware help/comments say disabled, while current resolution and profile enable it.
- A router comment says structural compressor overrides are env-backed. Actual proxy construction does not pass those objects, and no per-field env plumbing was found. Treat those constructors as custom Python integration controls.
- The docs describe all errors as preserved. Direct LogCompressor has explicit error/trace/warning caps. Small failed outputs have a separate verbatim protection gate; large logs can compress.
- Image docs expose constructor `model_id`, `use_siglip=true`, and `device=auto/cpu/cuda/mps`. No general proxy flags for those were verified. The current compressor selector can disable the image arm by selecting other arms, but it is a compressor-selection change, not a dedicated image switch.
- Source reads and skill instructions have explicit byte-exact protection lists. Generic tool exclusion alone is weaker because it can still allow structural folds.

This is a static source audit. No Headroom install, traffic replay, account login, or coding-outcome benchmark ran. Compression must be judged by completed tasks, retries, elapsed time, and provider usage.

## Existing setup

The repository inventories, refreshed 2026-10-27, record Ponytail, Agent Skills, Matt Pocock skills, Chrome DevTools, sync-worktrees, and Herdr integrations. They do not record Serena, Context7, RTK, or context-mode. These are inventory observations, not a fresh runtime test. Chrome DevTools is pinned to 1.12.0 in Claude; Codex uses `@latest --no-usage-statistics`.

Sources: [Claude inventory](/Users/yordan.kanchelov/projects/github/dotfiles/agent-setup/claude/inventory.md), [Codex inventory](/Users/yordan.kanchelov/projects/github/dotfiles/agent-setup/codex/inventory.md).

## Useful companions

| Component | What it adds | Recommendation |
| --- | --- | --- |
| Headroom MCP | Gives the model tools to recover originals from compressed context and inspect compression. | Include retrieval when using reversible compression. It is part of Headroom, not another memory product. [MCP docs](https://docs.headroomlabs.ai/docs/mcp) |
| Serena | Finds symbols and references, navigates source code, and performs symbol edits. It selects relevant source before the proxy processes requests. | Use one registration. `headroom wrap` already registers Serena by default, through `uvx`. Claude gets project-local scope unless overridden. [Headroom README](https://github.com/headroomlabs-ai/headroom) |
| Context7 | Retrieves current third-party library documentation. It does not index this working tree. | Best optional addition for framework-heavy work. Hosted MCP supports OAuth without a local Node runtime. [Claude guide](https://context7.com/docs/clients/claude-code) |
| Chrome DevTools | Runs and inspects browser behavior. | Keep the existing installation. Compression cannot verify an interface, console error, or network request. |
| sync-worktrees and Herdr | Existing worktree and terminal coordination. | Keep them. They solve a different problem from context compression. |
| Ponytail and existing engineering skills | Guide how the agent writes and works. | Keep them. Headroom itself recommends Serena plus Ponytail. [Headroom README](https://github.com/headroomlabs-ai/headroom) |

Serena is more useful in a large codebase than in this repository's Ansible YAML. Its Ansible support is experimental. The documented upstream language server lacks symbols, references, and rename. C/C++ benefits from `compile_commands.json`. [Language support](https://oraios.github.io/serena/01-about/020_programming-languages.html)

Serena's own memory files overlap with Headroom's persistent memory. Start with code navigation, and keep durable decisions in the existing project instructions. Serena can disable memory and onboarding with the `no-memories` base mode. Otherwise its Markdown memories live in `.serena/memories/` and `~/.serena/memories/global/`. [Memory documentation](https://oraios.github.io/serena/02-usage/045_memories.html)

## Actual Headroom plugins

| Plugin or extension | Purpose | Fit here |
| --- | --- | --- |
| Bundled `headroom-agent-hooks` | Runs `headroom init hook ensure` at Claude/Copilot session start and before Bash/PowerShell tools. Starts a matching durable deployment if needed. | Consider after a successful trial, if adopting `headroom init`. It adds startup behavior. Documentation covers Claude and Copilot, not Codex. [Agent hooks](https://docs.headroomlabs.ai/docs/agent-hooks) |
| `headroom-oauth2` | Mints and refreshes client-credentials tokens for enterprise OpenAI-compatible gateways. | Skip for normal Claude/Codex logins. This does not turn a subscription login into API access. [OAuth2 extension](https://docs.headroomlabs.ai/docs/oauth2-upstream) |
| Pipeline extensions | Inspect or change messages, tools, headers, and metadata at pipeline events. Packages register under `headroom.pipeline_extension`. | Add only for a concrete gateway incompatibility or required integration. Extensions execute inside the Headroom environment and can change provider-bound content. [Pipeline extensions](https://docs.headroomlabs.ai/docs/pipeline-extensions) |
| `routemegood` | Reference consumer of Headroom's per-request model-routing interface. | Skip during compression evaluation. Changing the model at the same time prevents a useful comparison. The documented routing advice interface does not cover the Responses API. [Routing contract](https://docs.headroomlabs.ai/docs/pipeline-extensions) |

Keep existing Herdr and Ponytail hooks when adding any startup plugin. Review the combined hooks rather than replacing the settings file. This is an integration recommendation, not a tested compatibility result.

## Headroom memory features are separate

| Feature | Meaning | Use here |
| --- | --- | --- |
| CCR and retrieval MCP | Retains exact pre-compression originals temporarily. The MCP-local default is one hour; the proxy default is 30 minutes. | Necessary recovery mechanism, not durable project memory. Recovery ends when the original expires. [MCP docs](https://docs.headroomlabs.ai/docs/mcp) |
| Persistent memory | Stores extracted facts across sessions, using local or remote embeddings. Default ONNX embeddings run on CPU. | Optional second experiment. Remote OpenAI embeddings send content to that service. [Memory docs](https://docs.headroomlabs.ai/docs/memory) |
| Proxy `--memory` | Enables memory and provider-specific tools. Anthropic cache mode skips automatic memory-context injection; OpenAI/Gemini append memory in the live section. | Do not enable it merely because compression is enabled. [Proxy options](https://docs.headroomlabs.ai/docs/proxy) |
| `headroom learn` | Analyzes prior session failures and proposes corrections to project instructions and memory. Default is dry-run; `--apply` writes files. | Review suggestions before applying. Claude defaults to `CLAUDE.local.md`, which should be gitignored, and its agent memory file. [Failure learning](https://docs.headroomlabs.ai/docs/failure-learning) |
| `SharedContext` | SDK object that stores handoff content and returns a compressed form or the original. | Skip unless building our own agent orchestration. It does not automatically connect independent terminal sessions. [SharedContext API](https://docs.headroomlabs.ai/docs/shared-context) |

## Verified integration details

Headroom's current source allows installation into selected agents. This avoids registering it in every detected agent:

```sh
headroom mcp install --agent claude --agent codex
```

This command changes agent configuration. It was not run. [CLI source](https://github.com/headroomlabs-ai/headroom/blob/main/headroom/cli/mcp.py)

For a manual stdio registration, the same process arguments work in each host. Point retrieval at the intended proxy instance:

```json
{
  "mcpServers": {
    "headroom": {
      "command": "headroom",
      "args": ["mcp", "serve", "--proxy-url", "http://127.0.0.1:8787"]
    }
  }
}
```

```toml
[mcp_servers.headroom]
command = "headroom"
args = ["mcp", "serve", "--proxy-url", "http://127.0.0.1:8787"]
```

Use an absolute executable path if the host cannot find `headroom`. A running proxy does not automatically expose an HTTP MCP endpoint. `headroom mcp serve --transport http` is a separate server. [MCP configuration](https://docs.headroomlabs.ai/docs/mcp)

Do not install an additional Serena plugin when Headroom manages the server. `headroom mcp reconcile` inspects Claude's registration and reports duplicate plugin servers; `--adopt` replaces the entry. Headroom's canonical Serena command is:

```sh
uvx --from serena-agent serena start-mcp-server --project-from-cwd --context claude-code --open-web-dashboard False
```

Use `--context codex` for Codex. The package argument is unpinned in current upstream source. Review and pin a working revision before making this portable setup policy. [Registration source](https://github.com/headroomlabs-ai/headroom/blob/main/headroom/mcp_registry/install.py)

Context7's hosted endpoint is `https://mcp.context7.com/mcp`. Its native plugins use OAuth. Its Codex guide documents a manual remote configuration with an Authorization header. Keep real credentials outside repository files. The `ctx7 setup --codex` alternative writes both config and `AGENTS.md`, so it is broader than adding one server. [Codex guide](https://context7.com/docs/clients/codex)

Inspect the wrapper's configuration changes before installing more context tools. The parallel runtime review found that its purge path targets legacy Headroom-managed RTK and lean-ctx artifacts. It leaves manually owned installations in place. Do not use that cleanup as a reason to remove unrelated plugins.

## Privacy and runtime costs

Serena reports anonymous startup metadata by default. Set `SERENA_USAGE_REPORTING=false` to opt out. The project says it does not send project data to its servers. Language servers can require additional runtimes and downloads. [Privacy](https://oraios.github.io/serena/01-about/070_privacy.html), [installation](https://oraios.github.io/serena/02-usage/010_installation.html)

Context7 receives the query formulated by the agent and the library identifier. It forwards queries to LLMs for reranking and stores queries anonymously for benchmarking, except Enterprise teamspaces. Instructions tell the agent to omit sensitive data; that is not a technical guarantee that a generated query contains none. The free account currently includes 1,000 monthly calls. [Data privacy](https://context7.com/docs/security/data-privacy), [plans](https://context7.com/docs/plans-pricing)

Headroom sees full agent traffic and provider credentials. CCR originals and persistent memories are not encrypted at rest. Stay on loopback. The user approved full-message logging for this trial; keep those files private and outside Git. The usage beacon is separate from local dashboard telemetry; `HEADROOM_BEACON=off` disables the beacon. [Security model](https://docs.headroomlabs.ai/docs/security-model), [telemetry options](https://docs.headroomlabs.ai/docs/proxy)

## Leave these out initially

RTK's command-filter core overlaps with Headroom's treatment of verbose shell output. Its current release also has an optional Engine and API proxy. The shell-rewrite path does not cover native Read/Grep/Glob tools. Headroom can retain only the output RTK supplied; recovery of earlier details depends on RTK's own capture or a raw rerun. Evaluate each tool separately first. The [RTK evaluation](2026-10-28-rtk-evaluation.md) covers editions, current hooks, recovery limits, and the Ansible filter's recap risk.

context-mode keeps large outputs in subprocesses and an index, then returns selected results. It also adds routing hooks and persistent session state. This overlaps with Headroom's compression, retrieval, and memory, and changes the tool workflow. Evaluate it as an alternative before stacking it. [context-mode](https://github.com/mksglu/context-mode)

No plugins were installed and no profiles were changed. These findings verify documented capabilities and selected source code, not end-to-end compatibility or savings on our tasks.
