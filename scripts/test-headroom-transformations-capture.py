"""Check optional Headroom request snapshots without network or live data."""

import argparse
import ast
import asyncio
from collections import deque
from copy import deepcopy
from dataclasses import dataclass, field, replace
import importlib.util
import json
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, help="Path to Headroom proxy/outcome.py")
options, test_args = parser.parse_known_args()
SOURCE = options.source
if SOURCE is not None and not SOURCE.is_file():
    parser.error(f"Headroom source does not exist: {SOURCE}")
if SOURCE is None:
    package = importlib.util.find_spec("headroom")
    if package and package.submodule_search_locations:
        SOURCE = Path(next(iter(package.submodule_search_locations))) / "proxy/outcome.py"


@unittest.skipUnless(SOURCE and SOURCE.is_file(), "optional Headroom source is not installed")
class SnapshotTests(unittest.TestCase):
    def setUp(self):
        tree = ast.parse(SOURCE.read_text())
        names = {"_request_projection", "RequestSnapshots", "RequestSnapshotQueue", "RequestOutcome"}
        nodes = [n for n in tree.body if isinstance(n, (ast.ClassDef, ast.FunctionDef)) and n.name in names]
        namespace = {"dataclass": dataclass, "field": field, "replace": replace, "deepcopy": deepcopy,
                     "deque": deque, "json": json}
        future = ast.ImportFrom(module="__future__", names=[ast.alias(name="annotations")], level=0)
        module = ast.fix_missing_locations(ast.Module(body=[future, *nodes], type_ignores=[]))
        name = "_headroom_capture_test"
        subject = types.ModuleType(name)
        subject.__dict__.update(namespace)
        sys.modules[name] = subject
        self.addCleanup(sys.modules.pop, name, None)
        exec(compile(module, str(SOURCE), "exec"), subject.__dict__)
        self.assertTrue(hasattr(subject, "RequestSnapshots"), "request capture fix is absent")
        self.snapshots = subject.RequestSnapshots
        self.queue = subject.RequestSnapshotQueue
        self.outcome = subject.RequestOutcome

    def pair(self, marker):
        pair = self.snapshots.capture(True, {"input": marker})
        pair.set_sent({"input": marker + "-sent"})
        return pair

    def test_projection_preserves_structures_and_schema_changes(self):
        original = {"instructions": "system", "input": [
            {"type": "message", "role": "user", "content": [{"type": "input_text", "text": "hello"}]},
            {"type": "function_call_output", "call_id": "call", "output": "tool output"}],
            "tools": [{"name": "read", "description": "long"}],
            "authorization": "excluded", "headers": {"x-api-key": "excluded"}}
        pair = self.snapshots.capture(True, {"type": "response.create", "response": original})
        sent = deepcopy(original)
        sent["tools"][0]["description"] = "short"
        pair.set_sent(json.dumps(sent).encode())
        original["input"].clear()
        self.assertEqual(len(pair.before[0]["input"]), 2)
        self.assertEqual(pair.after[0]["tools"][0]["description"], "short")
        self.assertEqual(set(pair.before[0]), {"instructions", "input", "tools"})

    def test_disabled_capture_does_not_copy_or_parse(self):
        class MustNotCopy:
            def __deepcopy__(self, memo):
                raise AssertionError("logging off copied content")
        self.assertIsNone(self.snapshots.capture(False, {"input": MustNotCopy()}))
        self.assertIsNone(self.snapshots.capture(False, b"invalid JSON"))

    def test_logging_fields_do_not_change_metrics(self):
        outcome = self.outcome(request_id="fixture", provider="openai", model="fixture",
                               original_tokens=100, optimized_tokens=80, output_tokens=5,
                               tokens_saved=20, attempted_input_tokens=100)
        captured = self.pair("before").apply(outcome)
        for key in vars(outcome):
            if key not in {"request_messages", "compressed_messages"}:
                self.assertEqual(getattr(outcome, key), getattr(captured, key))
        self.assertEqual(captured.request_messages[0]["input"], "before")
        self.assertEqual(captured.compressed_messages[0]["input"], "before-sent")

    def test_two_queued_turns_are_bound_to_created_ids(self):
        queue = self.queue()
        a, b = self.pair("normal"), self.pair("auto-review")
        queue.enqueue(a)
        queue.enqueue(b)
        queue.event({"type": "response.created", "response": {"id": "a"}})
        queue.event({"type": "response.created", "response": {"id": "b"}})
        self.assertIs(queue.event({"type": "response.completed", "response": {"id": "b"}}), b)
        self.assertIs(queue.event({"type": "response.completed", "response": {"id": "a"}}), a)
        self.assertIsNone(queue.event({"type": "response.completed", "response": {"id": "a"}}))

    def test_control_and_known_failure_do_not_shift_next_turn(self):
        queue = self.queue()
        queue.enqueue(self.pair("failed"))
        good = self.pair("good")
        queue.enqueue(good)
        queue.event({"type": "response.created", "response": {"id": "failed"}})
        queue.event({"type": "ping"})
        queue.event({"type": "response.failed", "response": {"id": "failed"}})
        queue.event({"type": "response.created", "response": {"id": "good"}})
        self.assertIs(queue.event({"type": "response.completed", "response": {"id": "good"}}), good)

    def test_uncorrelated_error_or_cancel_discards_stale_pairs(self):
        for event in ({"type": "error"}, {"type": "response.cancel"},
                      {"type": "response.incomplete", "response": {"id": "unknown"}}):
            with self.subTest(event=event):
                queue = self.queue()
                queue.enqueue(self.pair("stale"))
                queue.event(event)
                queue.enqueue(self.pair("new"))
                queue.event({"type": "response.created", "response": {"id": "next"}})
                self.assertIsNone(queue.event({"type": "response.completed", "response": {"id": "next"}}))

    def test_queue_overflow_discards_content_without_reassigning_it(self):
        queue = self.queue()
        for _ in range(101):
            queue.enqueue(self.pair("fixture"))
        self.assertTrue(queue.disabled)
        self.assertEqual(len(queue.pending) + len(queue.active), 0)
        queue.event({"type": "response.created", "response": {"id": "late"}})
        self.assertIsNone(queue.event({"type": "response.completed", "response": {"id": "late"}}))

    def test_duplicate_created_event_does_not_consume_the_next_turn(self):
        queue = self.queue()
        a, b = self.pair("a"), self.pair("b")
        queue.enqueue(a)
        queue.enqueue(b)
        for _ in range(2):
            queue.event({"type": "response.created", "response": {"id": "a"}})
        queue.event({"type": "response.created", "response": {"id": "b"}})
        self.assertIs(queue.event({"type": "response.completed", "response": {"id": "b"}}), b)

    def test_empty_create_keeps_its_fifo_position(self):
        queue = self.queue()
        empty = self.snapshots.capture(True, {"type": "response.create", "previous_response_id": "old"})
        full = self.pair("next")
        queue.enqueue(empty)
        queue.enqueue(full)
        queue.event({"type": "response.created", "response": {"id": "empty"}})
        queue.event({"type": "response.created", "response": {"id": "full"}})
        self.assertIs(queue.event({"type": "response.completed", "response": {"id": "empty"}}), empty)
        self.assertIs(queue.event({"type": "response.completed", "response": {"id": "full"}}), full)

    def test_existing_image_redaction_handles_the_projection(self):
        source = SOURCE.parent / "request_log_redaction_policy.py"
        if not source.is_file():
            self.skipTest("request image redactor is not beside outcome.py")
        name = "_headroom_redaction_test"
        spec = importlib.util.spec_from_file_location(name, source)
        policy = importlib.util.module_from_spec(spec)
        sys.modules[name] = policy
        self.addCleanup(sys.modules.pop, name, None)
        spec.loader.exec_module(policy)
        image = "data:image/png;base64," + "a" * 2048
        pair = self.snapshots.capture(True, {"input": [{"content": [
            {"type": "input_image", "image_url": image},
            {"type": "input_text", "text": "consented text"}]}]})
        result = policy.redact_image_base64_value(pair.before)
        blocks = result.value[0]["input"][0]["content"]
        self.assertEqual(result.redactions, 1)
        self.assertTrue(blocks[0]["image_url"].startswith("<image:base64-redacted"))
        self.assertEqual(blocks[1]["text"], "consented text")

    def test_buffered_dispatch_snapshots_exact_selected_bytes(self):
        source = SOURCE.parent / "server.py"
        if not source.is_file():
            self.skipTest("proxy server source is not beside outcome.py")
        method = next(n for n in ast.walk(ast.parse(source.read_text()))
                      if isinstance(n, ast.AsyncFunctionDef) and n.name == "_retry_request")
        future = ast.ImportFrom(module="__future__", names=[ast.alias(name="annotations")], level=0)
        module = ast.fix_missing_locations(ast.Module(body=[future, method], type_ignores=[]))
        namespace = {"RETRYABLE_OVERLOAD_STATUSES": set()}
        exec(compile(module, str(source), "exec"), namespace)
        forwarding = types.ModuleType("headroom.proxy.body_forwarding")
        forwarding.select_outbound_body = lambda **kwargs: types.SimpleNamespace(
            content=kwargs["original_body_bytes"], source="passthrough", dropped_mutation_reasons=[])
        helpers = types.ModuleType("headroom.proxy.helpers")
        helpers.log_outbound_request = lambda **kwargs: None
        sent = []

        async def post(url, **kwargs):
            sent.append(kwargs["content"])
            return types.SimpleNamespace(status_code=200)

        client = types.SimpleNamespace(config=types.SimpleNamespace(retry_max_attempts=1),
                                       http_client=types.SimpleNamespace(post=post))
        pair = self.snapshots.capture(True, {"input": "original"})
        actual = b'{"input":"actual selected bytes","tools":[]}'
        with patch.dict(sys.modules, {forwarding.__name__: forwarding, helpers.__name__: helpers}):
            asyncio.run(namespace["_retry_request"](
                client, "POST", "https://fixture.invalid", {}, {"input": "unused candidate"},
                original_body_bytes=actual, body_mutated=False, request_snapshots=pair))
        self.assertEqual(sent, [actual])
        self.assertEqual(pair.after, [{"input": "actual selected bytes", "tools": []}])

    def test_fallback_uses_actual_forwarded_bytes(self):
        pair = self.pair("original")
        pair.set_sent(b'{"input":[{"role":"user","content":"fallback"}],"stream":true}')
        self.assertEqual(pair.before[0]["input"], "original")
        self.assertEqual(pair.after[0]["input"][0]["content"], "fallback")


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0], *test_args])
