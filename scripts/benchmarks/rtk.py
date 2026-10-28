#!/usr/bin/env python3
"""Benchmark installed RTK filters on local synthetic commands; no provider calls."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import statistics
import subprocess
import tempfile
import time


ITERATIONS = 3
REFERENCE_REVISION = "753a3b0e939f2e4490fc24e3a1984010f40a103c"


def run_command(arguments, directory, environment):
    started = time.perf_counter()
    process = subprocess.run(
        arguments,
        cwd=directory,
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=60,
        check=False,
    )
    return {
        "exit_code": process.returncode,
        "output": process.stdout,
        "elapsed_ms": (time.perf_counter() - started) * 1000,
    }


def checked_command(arguments, directory, environment):
    result = run_command(arguments, directory, environment)
    if result["exit_code"] != 0:
        raise RuntimeError(f"Fixture command failed: {arguments[0]} (exit {result['exit_code']})")
    return result


def prepare_fixtures(root, environment):
    git = root / "git"
    git.mkdir()
    checked_command(["git", "init", "-b", "main"], git, environment)
    for index in range(12):
        (git / f"tracked-{index:03}.txt").write_text("baseline\n")
    checked_command(["git", "add", "."], git, environment)
    checked_command(
        ["git", "-c", "user.name=RTK Benchmark", "-c",
         "user.email=rtk-benchmark@example.invalid", "commit", "-m", "synthetic fixture"],
        git,
        environment,
    )
    for index in range(5):
        (git / f"tracked-{index:03}.txt").write_text("modified\n")
    for index in range(5, 8):
        (git / f"tracked-{index:03}.txt").unlink()
    for index in range(80):
        (git / f"untracked-{index:03}.txt").write_text("synthetic\n")

    cargo = root / "cargo"
    (cargo / "src").mkdir(parents=True)
    (cargo / "Cargo.toml").write_text(
        '[package]\nname="rtk_fixture"\nversion="0.1.0"\nedition="2024"\n'
    )
    tests = [f"#[test] fn passes_{index:02}() {{ assert_eq!({index}, {index}); }}"
             for index in range(40)]
    tests.extend([
        '#[test] fn missing_cache_key() { assert!(false, "diagnostic_missing_cache_key"); }',
        '#[test] fn invalid_schema() { assert_eq!(1, 2, "diagnostic_invalid_schema"); }',
    ])
    (cargo / "src/lib.rs").write_text("#[cfg(test)] mod tests {\n" + "\n".join(tests) + "\n}\n")

    lint = root / "lint"
    lint.mkdir()
    (lint / "eslint.config.mjs").write_text(
        'export default [{ files: ["**/*.js"], rules: '
        '{ "no-undef": "error", "no-unused-vars": "warn" } }];\n'
    )
    for index in range(35):
        diagnostic = "missing_fixture_name();\n" if index < 2 else ""
        (lint / f"file-{index:02}.js").write_text(f"const unused_{index} = {index};\n" + diagnostic)

    return [
        ("git_status", git, ["git", "status"], ["rtk", "git", "status"], 0,
         ["tracked-000.txt", "tracked-005.txt"], True),
        ("cargo_test", cargo, ["cargo", "test", "--color", "never"],
         ["rtk", "cargo", "test", "--color", "never"], 101,
         ["diagnostic_missing_cache_key", "diagnostic_invalid_schema", "40 passed; 2 failed"], True),
        ("eslint", lint, ["eslint", ".", "--no-color"], ["rtk", "lint", ".", "--no-color"], 1,
         ["no-undef", "missing_fixture_name", "2 errors, 35 warnings"], False),
    ]


def benchmark_case(case, environment):
    name, directory, baseline, filtered, expected_exit, markers, require_diagnostics = case
    run_command(baseline, directory, environment)
    run_command(filtered, directory, environment)
    baseline_runs = [run_command(baseline, directory, environment) for _ in range(ITERATIONS)]
    filtered_runs = [run_command(filtered, directory, environment) for _ in range(ITERATIONS)]
    raw = baseline_runs[-1]["output"]
    compact = filtered_runs[-1]["output"]
    (directory / "baseline-output.txt").write_bytes(raw)
    (directory / "rtk-output.txt").write_bytes(compact)

    if any(run["exit_code"] != expected_exit for run in baseline_runs + filtered_runs):
        raise RuntimeError(f"{name}: expected exit {expected_exit}; inspect saved outputs")
    diagnostics = {
        marker: {"baseline": marker.encode() in raw, "rtk": marker.encode() in compact}
        for marker in markers
    }
    if not all(check["baseline"] for check in diagnostics.values()):
        raise RuntimeError(f"{name}: baseline diagnostic missing")
    if require_diagnostics and not all(check["rtk"] for check in diagnostics.values()):
        raise RuntimeError(f"{name}: required diagnostic lost")

    return {
        "case": name,
        "raw_command": baseline,
        "rtk_command": filtered,
        "raw_exit_codes": [run["exit_code"] for run in baseline_runs],
        "rtk_exit_codes": [run["exit_code"] for run in filtered_runs],
        "expected_exit": expected_exit,
        "raw_bytes": len(raw),
        "rtk_bytes": len(compact),
        "raw_estimated_tokens": (len(raw) + 3) // 4,
        "rtk_estimated_tokens": (len(compact) + 3) // 4,
        "byte_reduction_pct": 100 * (len(raw) - len(compact)) / len(raw) if raw else 0,
        "raw_run_times_ms": [run["elapsed_ms"] for run in baseline_runs],
        "rtk_run_times_ms": [run["elapsed_ms"] for run in filtered_runs],
        "raw_warm_median_ms": statistics.median(run["elapsed_ms"] for run in baseline_runs),
        "rtk_warm_median_ms": statistics.median(run["elapsed_ms"] for run in filtered_runs),
        "key_diagnostics": diagnostics,
        "selected_diagnostics_preserved": all(check["rtk"] for check in diagnostics.values()),
        "stdout_sha256": {
            "baseline": hashlib.sha256(raw).hexdigest(),
            "rtk": hashlib.sha256(compact).hexdigest(),
        },
    }


def native_tracking(root):
    """Read only this benchmark's counters, without exposing command text."""
    database = root / "history.db"
    if not database.is_file():
        raise RuntimeError("RTK did not create the isolated tracking database")
    with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True) as connection:
        connection.execute("PRAGMA query_only=ON")
        result = {}
        for name, prefix in (("git_status", "rtk git status%"),
                             ("cargo_test", "rtk cargo test%"), ("eslint", "rtk lint%")):
            row = connection.execute(
                "SELECT input_tokens, output_tokens, saved_tokens FROM commands "
                "WHERE rtk_cmd LIKE ? ORDER BY id DESC LIMIT 1", (prefix,)
            ).fetchone()
            if row is None:
                raise RuntimeError(f"{name}: isolated native tracking record missing")
            result[name] = dict(zip(("input_estimated_tokens", "output_estimated_tokens",
                                     "saved_estimated_tokens"), row))
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="New output directory; existing paths are refused")
    options = parser.parse_args()
    repository = Path(__file__).resolve().parents[2]
    if options.output is not None:
        requested = options.output.expanduser()
        if requested.exists() or requested.is_symlink():
            parser.error("--output must name a new, nonexistent directory")
        if requested.resolve().is_relative_to(repository):
            parser.error("Benchmark output must stay outside the repository")
    elif Path(tempfile.gettempdir()).resolve().is_relative_to(repository):
        parser.error("The temporary directory is inside this repository; choose --output outside it")
    missing = [program for program in ("git", "cargo", "eslint", "rtk") if shutil.which(program) is None]
    if missing:
        parser.error("Required installed tools not found: " + ", ".join(missing))

    if options.output is None:
        root = Path(tempfile.mkdtemp(prefix="rtk-benchmark-")).resolve()
    else:
        root = options.output.expanduser().absolute()
        root.mkdir(mode=0o700)
        root = root.resolve()
    root.chmod(0o700)
    empty_template = root / "empty-git-template"
    empty_template.mkdir()
    # Git's ambient repository/index/config variables must not target a real checkout.
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    environment.update(RTK_DB_PATH=str(root / "history.db"),
                       RTK_RECALL_DB=str(root / "recall.db"), RTK_TELEMETRY_DISABLED="1",
                       RTK_ONRAMP_DISABLED="1", NO_COLOR="1", CARGO_NET_OFFLINE="true",
                       npm_config_offline="true", npm_config_yes="false", npm_config_ignore_scripts="true",
                       GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
                       GIT_TEMPLATE_DIR=str(empty_template))
    versions = {
        program: checked_command([program, "--version"], root, environment)["output"].decode().strip()
        for program in ("git", "cargo", "eslint", "rtk")
    }
    cases = prepare_fixtures(root, environment)
    results = [benchmark_case(case, environment) for case in cases]
    report = {
        "directory": str(root),
        "created_at": datetime.now(timezone.utc).isoformat(),
        "versions": versions,
        "rtk_version": versions["rtk"],
        "reference_rtk_revision": REFERENCE_REVISION,
        "benchmark_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "estimator": "ceil(UTF8_bytes / 4), native RTK text module",
        "iterations": "one warm-up each then 3 measured runs each",
        "isolated_tracking_db": str(root / "history.db"),
        "isolated_recall_db": str(root / "recall.db"),
        "config": "Existing RTK configuration read-only; tracking and recall paths overridden by environment",
        "scope": "Synthetic command-output reduction; not a native-hook or provider-billing benchmark",
        "native_tracking_note": (
            "Native counters can differ: RTK requests ESLint JSON instead of the baseline's stylish "
            "format, and may append recall hints after recording filtered output. Saved output files "
            "and their hashes define the visible-output comparison."
        ),
        "native_tracking_last_run": native_tracking(root),
        "results": results,
    }
    destination = root / "results.json"
    destination.write_text(json.dumps(report, indent=2) + "\n")
    destination.chmod(0o600)
    print(json.dumps({"results": str(destination), "cases": [
        {"case": row["case"], "byte_reduction_pct": row["byte_reduction_pct"],
         "selected_diagnostics_preserved": row["selected_diagnostics_preserved"]}
        for row in results
    ]}))


if __name__ == "__main__":
    main()
