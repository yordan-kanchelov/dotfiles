"""Benchmark synthetic Headroom fixtures offline; never call a running proxy."""

import argparse
from contextlib import ExitStack, contextmanager
from copy import deepcopy
import csv
from dataclasses import dataclass
from datetime import datetime, timezone
import hashlib
from importlib.metadata import PackageNotFoundError, version
import io
import json
import logging
import os
from pathlib import Path
import re
import socket
import statistics
import sys
import tempfile
from time import perf_counter
from types import SimpleNamespace
from unittest.mock import patch


VERSION = "0.42.0"
REPO_ROOT = Path(__file__).resolve().parents[2]
MODEL = "gpt-6.1-sol"
STRICT = "initial_lossless_baseline_9b40bc2"
ALTERNATIVE = "offline_structural_ccr_no_ml"
NEEDLES = (
    "ERROR_SENTINEL_001", "ID_SENTINEL_042", "PLAY RECAP", "changed=0", "ValueError",
    "diagnostic_missing_cache_key", "diagnostic_invalid_schema", "missing_fixture_name", "no-undef",
)


@dataclass
class Fixture:
    name: str
    messages: list
    original_output: str
    frozen_messages: int = 2


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New artifact directory; must not already exist")
    parser.add_argument("--rtk-fixtures", type=Path,
                        help="RTK benchmark directory with results.json and git/cargo/lint outputs")
    args = parser.parse_args()
    try:
        installed = version("headroom-ai")
    except PackageNotFoundError:
        parser.error("run with the Python from the installed Headroom proxy tool")
    if installed != VERSION:
        parser.error(f"this benchmark requires headroom-ai=={VERSION}; found {installed}")
    if args.output is not None:
        candidate = args.output.expanduser()
        if candidate.exists() or candidate.is_symlink():
            parser.error("--output must name a new directory")
        destination = candidate.resolve()
    else:
        destination = Path(tempfile.gettempdir()).resolve()
    if destination == REPO_ROOT or REPO_ROOT in destination.parents:
        parser.error("benchmark artifacts must be outside the repository")
    return parser, args


def configure_isolation(output):
    for key in list(os.environ):
        if key.startswith(("HEADROOM_", "OPENAI_", "ANTHROPIC_", "HF_", "TRANSFORMERS_")):
            os.environ.pop(key, None)
    state = output / "state"
    state.mkdir(mode=0o700)
    os.environ.update({
        "HEADROOM_WORKSPACE_DIR": str(state),
        "HEADROOM_CONFIG_DIR": str(state / "config"),
        "HEADROOM_SETTINGS_PATH": str(state / "settings.json"),
        "HEADROOM_MODE": "cache",
        "HEADROOM_SAVINGS_PROFILE": "coding",
        "HEADROOM_LOSSLESS": "1",
        "HEADROOM_NO_CCR": "1",
        "HEADROOM_CCR_BACKEND": "memory",
        "HEADROOM_CCR_TTL_SECONDS": "3600",
        "HEADROOM_PROTECT_READS": "1",
        "HEADROOM_COMPRESS_SYSTEM_MESSAGES": "0",
        "HEADROOM_COMPRESSORS": "smart_crusher,kompress,code_aware,search,log,tabular,config,html",
        "HEADROOM_DISABLE_FEATURES": "proxy_output_shaper,tool_result_interceptors,read_maturation",
        "HEADROOM_OUTPUT_SHAPER": "0",
        "HEADROOM_CODE_MEMORY": "none",
        "HEADROOM_TELEMETRY": "off",
        "HEADROOM_BEACON": "off",
        "HEADROOM_UPDATE_CHECK": "off",
        "HEADROOM_NO_SUBSCRIPTION_TRACKING": "1",
        "HEADROOM_OFFLINE": "1",
        "HF_HUB_OFFLINE": "1",
        "TRANSFORMERS_OFFLINE": "1",
        "HEADROOM_TIKTOKEN_LOAD_TIMEOUT_SECONDS": "1",
    })
    logging.disable(logging.CRITICAL)


@contextmanager
def deny_network():
    blocked = []

    def reject(*args, **kwargs):
        blocked.append("blocked")
        raise RuntimeError("network disabled for offline benchmark")

    with ExitStack() as stack:
        for target in ("socket.create_connection", "socket.getaddrinfo", "socket.socket.connect",
                       "socket.socket.connect_ex", "socket.socket.sendto"):
            stack.enter_context(patch(target, reject))
        yield blocked


def messages_for(text, *, tool="Bash", command="pytest -q", system=None):
    return [
        {"role": "system", "content": system or "Keep exact error identifiers."},
        {"role": "user", "content": "Report the test results, retaining exact error identifiers."},
        {"role": "assistant", "content": "", "tool_calls": [{
            "id": "synthetic-call", "type": "function", "function": {
                "name": tool, "arguments": json.dumps({"command": command, "file_path": "fixture.py"}),
            },
        }]},
        {"role": "tool", "tool_call_id": "synthetic-call", "content": text},
    ]


def make_fixtures():
    repeated = "INFO worker healthy request_id=REPEAT-0101\n" * 500
    repeated += "ERROR ERROR_SENTINEL_001 cache key ID_SENTINEL_042 missing\n"
    unique = "".join(f"INFO request ID-{i:04d} completed output_hash={i * 7919:08x}\n" for i in range(100))
    unique += "ERROR ERROR_SENTINEL_001 ID_SENTINEL_042 failed\n"
    records = [{
        "id": f"RECORD-{i:04d}", "status": "error" if i == 57 else "ok",
        "message": "ERROR_SENTINEL_001 ID_SENTINEL_042" if i == 57 else f"unique-value-{i:04d}",
        "enabled": True, "count": i,
    } for i in range(100)]
    source = "\n".join(f'{i + 1:4d}  def helper_{i}(): return "VALUE-{i:04d}"' for i in range(100))
    source += '\nERROR_SENTINEL_001 = "ID_SENTINEL_042"\n'
    search = "".join(f"src/repeated/subdirectory/module.py:{i + 1}:ID-{i:04d} use_value({i})\n" for i in range(100))
    search += "src/repeated/subdirectory/module.py:999:ERROR_SENTINEL_001 ID_SENTINEL_042\n"
    ansible = ("PLAY [localhost]\nTASK [check configuration]\nok: [localhost]\nPLAY RECAP\n"
               "localhost : ok=4 changed=0 unreachable=0 failed=0 skipped=2 rescued=0 ignored=0\n")
    python = ('Traceback (most recent call last):\n  File "fixture.py", line 42, in <module>\n'
              '    run()\nValueError: ERROR_SENTINEL_001 ID_SENTINEL_042\n')
    fixtures = [
        Fixture("repeated_build_log", messages_for(repeated), repeated),
        Fixture("unique_build_log", messages_for(unique), unique),
        Fixture("pretty_json_records", messages_for(json.dumps(records, indent=2), command="curl fixture"),
                json.dumps(records, indent=2)),
        Fixture("source_read", messages_for(source, tool="Read", command=""), source),
        Fixture("source_cat", messages_for(source, command="cat fixture.py"), source),
        Fixture("search_results", messages_for(search, command="rg use_value src"), search),
        Fixture("ansible_recap", messages_for(ansible, command="ansible-playbook fixture.yml"), ansible),
        Fixture("python_error", messages_for(python, command="python fixture.py"), python),
        Fixture("system_prompt_protected", messages_for("done", system=repeated), "done", 0),
    ]
    history = messages_for(source, tool="Read", command="", system="Fixed prefix.\n" + unique * 20)
    history[2]["tool_calls"][0]["id"] = "synthetic-old-call"
    history[3]["tool_call_id"] = "synthetic-old-call"
    history += messages_for(repeated)[1:]
    fixtures.append(Fixture("frozen_history_new_log", history, repeated, len(history) - 2))
    return fixtures


def csv_fixture_equal(original, final):
    """Decode only the flat int/bool/string CSV-schema fixture used here."""
    lines = final.splitlines()
    header = re.fullmatch(r"\[(\d+)\]\{(.+)\}", lines[0]) if lines else None
    if header is None:
        return False
    columns = [part.split(":", 1) for part in header.group(2).split(",")]
    decoded = []
    for row in csv.reader(io.StringIO("\n".join(lines[1:]))):
        if len(row) != len(columns):
            return False
        record = {}
        for (key, kind), value in zip(columns, row):
            if kind == "int":
                value = int(value)
            elif kind == "bool":
                if value not in ("true", "false"):
                    return False
                value = value == "true"
            elif kind != "string":
                return False
            record[key] = value
        decoded.append(record)
    return (len(decoded) == int(header.group(1))
            and json.dumps(decoded, sort_keys=True) == json.dumps(json.loads(original), sort_keys=True))


def roundtrip_proof(original, final):
    from headroom.transforms.lossless_compaction import (
        expand_runs, path_unheading, search_dir_unheading, search_unheading, unfold_repeated_blocks,
    )
    if final == original:
        return "byte_identical_utf8_content"
    try:
        if json.dumps(json.loads(final), sort_keys=True) == json.dumps(json.loads(original), sort_keys=True):
            return "json_data_equal"
    except (ValueError, TypeError):
        pass
    try:
        if csv_fixture_equal(original, final):
            return "fixture_csv_schema_data_equal"
    except (ValueError, TypeError, IndexError):
        pass
    for inverse in (expand_runs, unfold_repeated_blocks, search_unheading, search_dir_unheading, path_unheading):
        if inverse(final) == original:
            return inverse.__name__
    return None


def make_pipeline(strict, provider):
    from headroom.cache.compression_store import reset_compression_store
    from headroom.config import CacheAlignerConfig, RelevanceScorerConfig
    from headroom.transforms.cache_aligner import CacheAligner
    from headroom.transforms.content_router import ContentRouter, ContentRouterConfig
    from headroom.transforms.pipeline import TransformPipeline

    reset_compression_store()  # Only this process's isolated in-memory store.
    config = ContentRouterConfig(
        enable_code_aware=True, enable_kompress=False, enable_image_optimizer=False,
        lossless=strict, ccr_enabled=not strict, ccr_inject_marker=not strict,
        smart_crusher_lossless_only=strict, smart_crusher_max_items_after_crush=15,
        smart_crusher_with_compaction=True, result_cache_disk=False,
        relevance_split=False, relevance=RelevanceScorerConfig(tier="bm25"),
    )
    return TransformPipeline(transforms=[CacheAligner(CacheAlignerConfig(enabled=False)),
                                         ContentRouter(config)], provider=provider)


def measure(fixture, strict, provider, counter, kwargs, output):
    os.environ["HEADROOM_LOSSLESS"] = "1" if strict else "0"
    os.environ["HEADROOM_NO_CCR"] = "1" if strict else "0"
    pipeline = make_pipeline(strict, provider)
    durations = []
    for _ in range(4):
        started = perf_counter()
        result = pipeline.apply(deepcopy(fixture.messages), MODEL,
                                frozen_message_count=fixture.frozen_messages, **kwargs)
        durations.append((perf_counter() - started) * 1000)
    final = result.messages[-1].get("content", "")
    arm = STRICT if strict else ALTERNATIVE
    folder = output / arm
    folder.mkdir(exist_ok=True)
    final_path = folder / f"{fixture.name}.txt"
    final_path.write_text(final)
    needles = {needle: needle in final for needle in NEEDLES if needle in fixture.original_output}
    record_ids = set(re.findall(r"RECORD-\d{4}", fixture.original_output))
    item = {
        "case": fixture.name, "arm": arm,
        "tokens_before": result.tokens_before, "tokens_after": result.tokens_after,
        "saved": result.tokens_before - result.tokens_after,
        "whole_message_reduction_pct": round(100 * (1 - result.tokens_after / result.tokens_before), 3),
        "output_tokens_before": counter.count_text(fixture.original_output),
        "output_tokens_after": counter.count_text(final),
        "first_call_ms": round(durations[0], 3),
        "warm3_ms": [round(value, 3) for value in durations[1:]],
        "warm3_median_ms": round(statistics.median(durations[1:]), 3),
        "transforms": result.transforms_applied, "warnings": result.warnings,
        "critical_needles": needles, "record_ids_total": len(record_ids),
        "record_ids_visible": sum(identifier in final for identifier in record_ids),
        "roundtrip_proof": roundtrip_proof(fixture.original_output, final),
        "ccr_marker": bool(re.search(r"<<ccr:|Retrieve full|headroom_retrieve", final)),
        "frozen_prefix_messages_equal": result.messages[:fixture.frozen_messages] == fixture.messages[:fixture.frozen_messages],
        "system_prompt_message_equal": result.messages[0] == fixture.messages[0],
        "output_path": str(final_path),
    }
    if strict:
        assert all(needles.values()), f"critical content lost in {fixture.name}"
        assert item["frozen_prefix_messages_equal"] and item["system_prompt_message_equal"]
        assert not item["ccr_marker"], f"unexpected CCR marker in {fixture.name}"
        assert item["roundtrip_proof"] is not None, f"no roundtrip proof for {fixture.name}"
        assert item["record_ids_visible"] == item["record_ids_total"]
        if fixture.name in {"source_read", "source_cat"}:
            assert final == fixture.original_output, f"file-read bytes changed in {fixture.name}"
    return item, final


def rtk_inputs(directory):
    if directory is None:
        return []
    metadata = json.loads((directory / "results.json").read_text(encoding="utf-8"))
    expected = metadata.get("results") if isinstance(metadata, dict) else None
    if not isinstance(expected, list):
        raise ValueError("RTK results.json must contain a results list")
    inputs = []
    for name, command in (("git", "git status"), ("cargo", "cargo test"), ("lint", "eslint fixture")):
        raw = (directory / name / "baseline-output.txt").read_bytes()
        filtered = (directory / name / "rtk-output.txt").read_bytes()
        hashes = {"baseline": hashlib.sha256(raw).hexdigest(), "rtk": hashlib.sha256(filtered).hexdigest()}
        if not any(isinstance(row, dict) and row.get("stdout_sha256") == hashes for row in expected):
            raise ValueError(f"RTK fixture hashes do not match results.json: {name}")
        inputs.append((name, command, raw, filtered, hashes))
    return inputs


def measure_chain(inputs, provider, counter, kwargs, output):
    results = []
    folder = output / "fixtures" / "rtk"
    if inputs:
        folder.mkdir()
        (folder / "results.json").write_text(json.dumps({
            "results": [{"case": name, "stdout_sha256": hashes}
                        for name, _, _, _, hashes in inputs],
        }, indent=2) + "\n", encoding="utf-8")
    for name, command, raw_bytes, rtk_bytes, hashes in inputs:
        case_dir = folder / name
        case_dir.mkdir()
        (case_dir / "baseline-output.txt").write_bytes(raw_bytes)
        (case_dir / "rtk-output.txt").write_bytes(rtk_bytes)
        raw, filtered = raw_bytes.decode("utf-8"), rtk_bytes.decode("utf-8")
        hr_item, hr = measure(Fixture(f"raw_chain_{name}", messages_for(raw, command=command), raw),
                              True, provider, counter, kwargs, output)
        both_item, both = measure(Fixture(f"rtk_chain_{name}", messages_for(filtered, command=command), filtered),
                                  True, provider, counter, kwargs, output)
        output_texts = {"raw": raw, "rtk": filtered, "headroom_only": hr, "both": both}
        results.append({
            "case": name, "fixture_hashes_verified": True, "stdout_sha256": hashes,
            "output_bytes": {arm: len(text.encode("utf-8")) for arm, text in output_texts.items()},
            "output_estimated_tokens": {arm: counter.count_text(text) for arm, text in output_texts.items()},
            "whole_message_tokens": {
                "raw": hr_item["tokens_before"], "rtk": both_item["tokens_before"],
                "headroom_only": hr_item["tokens_after"], "both": both_item["tokens_after"],
            },
            "raw_needles_by_arm": {needle: {arm: needle in text for arm, text in output_texts.items()}
                                   for needle in (*NEEDLES, "tracked-000.txt") if needle in raw},
            "headroom_only_warm3_median_ms": hr_item["warm3_median_ms"],
            "headroom_after_rtk_warm3_median_ms": both_item["warm3_median_ms"],
            "headroom_only_roundtrip": hr_item["roundtrip_proof"],
            "headroom_after_rtk_roundtrip": both_item["roundtrip_proof"],
            "headroom_only_path": hr_item["output_path"], "both_path": both_item["output_path"],
        })
    return results


def measure_tools(counter):
    from headroom.proxy.tool_schema_compaction import compact_tools
    tools = [{
        "type": "function", "name": f"fixture_tool_{i}",
        "description": "  Perform   the   fixture operation.  ",
        "parameters": {"type": "object", "title": "Fixture parameter schema",
                       "properties": {"id": {"type": "string", "description": "  Unique   identifier.  ",
                                              "examples": ["ID_SENTINEL_042"]}},
                       "required": ["id"], "additionalProperties": False},
    } for i in range(20)]
    durations = []
    for _ in range(4):
        started = perf_counter()
        updated, modified, _, _ = compact_tools({"tools": deepcopy(tools)})
        durations.append((perf_counter() - started) * 1000)
    compacted = updated["tools"]
    return {
        "before_tokens": counter.count_text(json.dumps(tools, separators=(",", ":"))),
        "after_tokens": counter.count_text(json.dumps(compacted, separators=(",", ":"))),
        "modified": modified,
        "names_preserved": [tool["name"] for tool in tools] == [tool["name"] for tool in compacted],
        "required_preserved": [tool["parameters"]["required"] for tool in tools] == [tool["parameters"]["required"] for tool in compacted],
        "property_names_preserved": [list(tool["parameters"]["properties"]) for tool in tools] == [list(tool["parameters"]["properties"]) for tool in compacted],
        "warm3_median_ms": round(statistics.median(durations[1:]), 3),
        "fidelity_scope": "Selected schema fields checked; annotations may be removed. No agent accuracy test.",
    }


def benchmark(output, inputs, blocked):
    from headroom.agent_savings import proxy_pipeline_kwargs, seed_proxy_env_defaults
    from headroom.providers.openai import OpenAIProvider
    from headroom.proxy.auth_mode import AuthMode
    from headroom.transforms.compression_policy import policy_for_mode
    from headroom.transforms.content_router import ContentRouter
    from headroom.transforms.pipeline import TransformPipeline

    assert callable(ContentRouter.apply) and callable(ContentRouter.compress)
    assert callable(TransformPipeline.apply) and callable(proxy_pipeline_kwargs)
    seed_proxy_env_defaults()
    provider = OpenAIProvider()
    counter = provider.get_token_counter(MODEL)
    kwargs = proxy_pipeline_kwargs(SimpleNamespace(savings_profile="coding"))
    assert kwargs["compress_user_messages"] and not kwargs["compress_system_messages"]
    assert kwargs["protect_recent"] == 0 and kwargs["min_tokens_to_compress"] == 10
    kwargs.update(model_limit=1_000_000, record_metrics=False,
                  compression_policy=policy_for_mode(AuthMode.SUBSCRIPTION))
    fixtures = make_fixtures()
    fixture_dir = output / "fixtures"
    fixture_dir.mkdir()
    for fixture in fixtures:
        (fixture_dir / f"{fixture.name}.json").write_text(json.dumps({
            "messages": fixture.messages, "original_output": fixture.original_output,
            "frozen_message_count": fixture.frozen_messages,
        }, indent=2) + "\n")
    results = [measure(fixture, strict, provider, counter, kwargs, output)[0]
               for strict in (True, False) for fixture in fixtures]
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(), "headroom_version": VERSION,
        "benchmark_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "model": MODEL, "token_counter": type(counter).__name__,
        "encoding_name": getattr(counter, "encoding_name", getattr(getattr(counter, "_encoding", None), "name", None)),
        "counter_units": "Installed model-specific local counter; fallback estimates are not BPE or RTK ceil(bytes/4).",
        "network_attempts_blocked": len(blocked),
        "scope": "Offline message TransformPipeline/ContentRouter, not the current service or full Responses transport.",
        "scenarios": {STRICT: "Initial lossless/no-CCR coding baseline from commit 9b40bc2.",
                      ALTERNATIVE: "Lossless disabled, CCR permitted, structural compressors only."},
        "scope_overrides": [
            "Kompress and image optimizer disabled; no model loading. Kompress is unreachable in strict lossless mode.",
            "Relevance split disabled and BM25 selected. No embedding models are loaded.",
            "New router and in-memory CCR/cache state per fixture. Four identical calls: first call plus three warm calls.",
            "First-call times across scenarios share imported libraries; do not compare them as cold startup costs.",
            "No native Responses unit extraction, HTTP routing, provider prefix-cache behavior, billing, quota, or task-quality measurement.",
            "Frozen-prefix equality compares message objects, not native HTTP wire bytes.",
        ],
        "pipeline_kwargs": {key: value for key, value in kwargs.items()
                            if isinstance(value, (str, int, float, bool, type(None)))},
        "fixtures": results, "rtk_chain_included": bool(inputs),
        "rtk_chain": measure_chain(inputs, provider, counter, kwargs, output),
        "tool_schema_pass": measure_tools(counter),
    }


def main():
    # This script's filename must not shadow the installed headroom package.
    script_dir = Path(__file__).resolve().parent
    sys.path[:] = [entry for entry in sys.path if Path(entry).resolve() != script_dir]
    parser, args = parse_args()
    try:
        inputs = rtk_inputs(args.rtk_fixtures.expanduser().resolve() if args.rtk_fixtures else None)
        if args.output is None:
            output = Path(tempfile.mkdtemp(prefix="headroom-benchmark-"))
        else:
            output = args.output.expanduser().resolve()
            output.mkdir(mode=0o700, exist_ok=False)
        configure_isolation(output)
        with deny_network() as blocked:
            report = benchmark(output, inputs, blocked)
            report["network_attempts_blocked"] = len(blocked)
        path = output / "results.json"
        path.write_text(json.dumps(report, indent=2) + "\n")
    except (OSError, ValueError, KeyError, RuntimeError, AssertionError) as error:
        parser.exit(1, f"Benchmark failed: {error}\n")
    print(f"Results: {path}")
    print(f"Counter: {report['token_counter']} | Network attempts blocked: {report['network_attempts_blocked']}")
    for result in report["fixtures"]:
        if result["arm"] == STRICT:
            print(f"{result['case']}: {result['tokens_before']} -> {result['tokens_after']} "
                  f"local tokens; warm median {result['warm3_median_ms']:.3f} ms")


if __name__ == "__main__":
    main()
