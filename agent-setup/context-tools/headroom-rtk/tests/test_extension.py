"""Exercise the RTK extension with temporary fake executables and ASGI requests."""

import asyncio
import gzip
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
DEPENDENCIES = all(importlib.util.find_spec(name) for name in ("fastapi", "httpx", "headroom"))
if DEPENDENCIES:
    import httpx
    from fastapi import FastAPI
    from starlette.responses import HTMLResponse, Response, StreamingResponse
    from headroom_rtk import extension


SUMMARY = {"total_commands": 8, "total_input": 2000, "total_output": 1800,
           "total_saved": 1000, "avg_savings_pct": 50.0}


@unittest.skipUnless(DEPENDENCIES, "run with the Headroom proxy tool's Python")
class ExtensionTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.binary = Path(scratch.name) / "rtk"

    def executable(self, body):
        self.binary.write_text(f"#!{sys.executable}\n" + body)
        self.binary.chmod(0o700)
        return patch.object(extension, "_find_rtk", return_value=str(self.binary))

    async def test_collects_only_allowed_summary_fields_with_fixed_arguments(self):
        data = {"summary": {**SUMMARY, "command": "private command"}, "daily": ["private data"]}
        body = ("import json,sys,os\n"
                "assert sys.argv[1:] == ['gain','--all','--format','json']\n"
                "assert os.environ['RTK_TELEMETRY_DISABLED'] == '1'\n"
                f"print({json.dumps(data)!r})\n")
        with self.executable(body):
            result = await extension._collect()
        self.assertTrue(result["available"])
        self.assertEqual(result["summary"], SUMMARY)
        self.assertNotIn("private", json.dumps(result))

    async def test_invalid_numbers_are_unavailable(self):
        for value in (-1, True, 1.5, float("inf"), "10"):
            with self.subTest(value=value):
                data = {"summary": {**SUMMARY, "total_saved": value}}
                with self.executable(f"print({json.dumps(data)!r})\n"):
                    result = await extension._collect()
                self.assertFalse(result["available"])
                self.assertEqual(result["reason"], "invalid_data")

    async def test_native_percentage_is_validated_without_clamping_or_recomputing(self):
        for value in (0, 42.125, 100):
            with self.subTest(value=value):
                data = {"summary": {**SUMMARY, "avg_savings_pct": value}}
                with self.executable(f"print({json.dumps(data)!r})\n"):
                    result = await extension._collect()
                self.assertEqual(result["summary"]["avg_savings_pct"], value)
        for value in (-5.0, 105.0, float("nan"), float("inf"), True):
            with self.subTest(value=value):
                data = {"summary": {**SUMMARY, "avg_savings_pct": value}}
                with self.executable(f"print({json.dumps(data)!r})\n"):
                    self.assertEqual((await extension._collect())["reason"], "invalid_data")

    async def test_failure_output_is_never_returned(self):
        with self.executable("import sys\nprint('private failure',file=sys.stderr)\nsys.exit(1)\n"):
            result = await extension._collect()
        self.assertEqual(result["reason"], "command_failed")
        self.assertNotIn("private", json.dumps(result))
        with self.executable("print('not JSON with private output')\n"):
            result = await extension._collect()
        self.assertEqual(result["reason"], "invalid_data")

    async def test_missing_timeout_and_oversized_output_are_neutral(self):
        with patch.object(extension, "_find_rtk", return_value=None):
            self.assertEqual((await extension._collect())["reason"], "not_installed")
        with self.executable("import time\ntime.sleep(30)\n"), patch.object(extension, "TIMEOUT_SECONDS", 0.1):
            self.assertEqual((await extension._collect())["reason"], "timeout")
        with self.executable("print('x'*4096)\n"), patch.object(extension, "MAX_OUTPUT_BYTES", 128):
            self.assertEqual((await extension._collect())["reason"], "invalid_data")

    async def test_cache_serializes_refresh_and_expires(self):
        clock = [100.0]
        entered, release = asyncio.Event(), asyncio.Event()

        async def collect():
            entered.set()
            await release.wait()
            return {"available": True}

        reader = AsyncMock(side_effect=collect)
        with patch.object(extension, "monotonic", side_effect=lambda: clock[0]), \
                patch.object(extension, "_collect", reader):
            cache = extension.StatsCache()
            first = asyncio.create_task(cache.get())
            await entered.wait()
            others = [asyncio.create_task(cache.get()) for _ in range(19)]
            await asyncio.sleep(0)
            self.assertEqual(reader.await_count, 1)
            release.set()
            await asyncio.gather(first, *others)
            clock[0] += 16
            await cache.get()
            self.assertEqual(reader.await_count, 2)

    def app(self):
        app = FastAPI()
        extension.install(app, SimpleNamespace())

        @app.get("/dashboard")
        async def dashboard():
            return HTMLResponse("<html><body>native dashboard</body></html>",
                                headers={"etag": "old", "content-security-policy": "script-src 'self'"})

        @app.get("/api-fixture")
        async def api():
            return {"untouched": True}

        return app

    async def test_dashboard_injection_and_routes_preserve_native_gate(self):
        app = self.app()

        @app.middleware("http")
        async def native_gate(request, call_next):
            if request.headers.get("x-fixture-auth") != "approved":
                return Response(status_code=401)
            response = await call_next(request)
            response.headers["x-content-type-options"] = "nosniff"
            return response

        transport = httpx.ASGITransport(app=app, client=("127.0.0.1", 12345))
        with patch.object(extension, "_collect", AsyncMock(return_value={"available": False})):
            async with httpx.AsyncClient(transport=transport, base_url="http://127.0.0.1") as client:
                self.assertEqual((await client.get("/dotfiles/rtk/stats")).status_code, 401)
                response = await client.get("/dashboard", headers={"x-fixture-auth": "approved"})
                self.assertIn('/dotfiles/rtk/panel.js', response.text)
                self.assertEqual(int(response.headers["content-length"]), len(response.content))
                self.assertNotIn("etag", response.headers)
                self.assertEqual(response.headers["content-security-policy"], "script-src 'self'")
                self.assertEqual(response.headers["x-content-type-options"], "nosniff")
                response = await client.get("/dotfiles/rtk/panel.js", headers={"x-fixture-auth": "approved"})
                self.assertEqual(response.status_code, 200)
                response = await client.get("/dotfiles/rtk/stats", headers={"x-fixture-auth": "approved"})
                self.assertEqual(response.status_code, 200)
                response = await client.get("/api-fixture", headers={"x-fixture-auth": "approved"})
                self.assertEqual(response.json(), {"untouched": True})

    async def test_remote_or_rebinding_clients_cannot_read_aggregates(self):
        for host, address in (("127.0.0.1", "203.0.113.1"), ("attacker.invalid", "127.0.0.1")):
            app = self.app()
            transport = httpx.ASGITransport(app=app, client=(address, 12345))
            with patch.object(extension, "_collect", AsyncMock()) as reader:
                async with httpx.AsyncClient(transport=transport, base_url=f"http://{host}") as client:
                    self.assertEqual((await client.get("/dotfiles/rtk/stats")).status_code, 404)
                    self.assertEqual((await client.get("/dotfiles/rtk/panel.js")).status_code, 404)
            reader.assert_not_awaited()

    async def test_remote_browser_origin_is_rejected_before_collection(self):
        app = self.app()
        transport = httpx.ASGITransport(app=app, client=("127.0.0.1", 12345))
        with patch.object(extension, "_collect", AsyncMock(return_value={"available": False})) as reader:
            async with httpx.AsyncClient(transport=transport, base_url="http://127.0.0.1") as client:
                for origin in ("https://attacker.invalid", "null"):
                    for path in ("/dotfiles/rtk/stats", "/dotfiles/rtk/panel.js"):
                        self.assertEqual((await client.get(path, headers={"origin": origin})).status_code, 403)
                reader.assert_not_awaited()
                self.assertEqual((await client.get("/dotfiles/rtk/stats", headers={"origin": "http://127.0.0.1"})).status_code, 200)

    async def test_small_streamed_dashboard_is_injected_but_encoding_is_untouched(self):
        for encoded in (False, True):
            app = FastAPI()
            extension.install(app, SimpleNamespace())

            @app.get("/dashboard")
            async def dashboard():
                if encoded:
                    return Response(gzip.compress(b"<html><body>encoded fixture</body></html>"),
                                    media_type="text/html", headers={"content-encoding": "gzip"})
                async def chunks():
                    yield b"<html><body>"
                    yield b"stream</bo"
                    yield b"dy></html>"
                return StreamingResponse(chunks(), media_type="text/html")

            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(transport=transport, base_url="http://127.0.0.1") as client:
                response = await client.get("/dashboard")
            if encoded:
                self.assertNotIn(b"/dotfiles/rtk/panel.js", response.content)
            else:
                self.assertIn(b"/dotfiles/rtk/panel.js", response.content)
                self.assertEqual(int(response.headers["content-length"]), len(response.content))

    async def test_inner_native_basehttp_middleware_does_not_hide_html(self):
        app = FastAPI()

        @app.middleware("http")
        async def native_inner(request, call_next):
            return await call_next(request)

        extension.install(app, SimpleNamespace())

        @app.get("/dashboard")
        async def dashboard():
            return HTMLResponse("<html><body>native</body></html>",
                                headers={"content-security-policy": "script-src 'self'"})

        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://127.0.0.1") as client:
            response = await client.get("/dashboard")
        self.assertIn(b"/dotfiles/rtk/panel.js", response.content)
        self.assertEqual(int(response.headers["content-length"]), len(response.content))
        self.assertEqual(response.headers["content-security-policy"], "script-src 'self'")

    async def test_dashboard_buffer_overflow_preserves_original_messages(self):
        messages = [
            {"type": "http.response.start", "status": 200,
             "headers": [(b"content-type", b"text/html"), (b"etag", b"original")]},
            {"type": "http.response.body", "body": b"<html><body>", "more_body": True},
            {"type": "http.response.body", "body": b"x" * 256, "more_body": True},
            {"type": "http.response.body", "body": b"</body></html>", "more_body": False},
        ]
        seen = []

        async def upstream(scope, receive, send):
            for message in messages:
                await send(message)

        async def send(message):
            seen.append(message)

        with patch.object(extension, "MAX_DASHBOARD_BYTES", 128):
            await extension.DashboardScript(upstream)(
                {"type": "http", "method": "GET", "path": "/dashboard"}, None, send)
        self.assertEqual(seen, messages)

    async def test_empty_chunks_cannot_grow_the_dashboard_buffer_without_limit(self):
        messages = [
            {"type": "http.response.start", "status": 200, "headers": [(b"content-type", b"text/html")]},
            *[{"type": "http.response.body", "body": b"", "more_body": True} for _ in range(4)],
            {"type": "http.response.body", "body": b"<body>native</body>", "more_body": False},
        ]
        seen = []

        async def upstream(scope, receive, send):
            for message in messages:
                await send(message)

        async def send(message):
            seen.append(message)

        with patch.object(extension, "MAX_DASHBOARD_CHUNKS", 2):
            await extension.DashboardScript(upstream)(
                {"type": "http", "method": "GET", "path": "/dashboard"}, None, send)
        self.assertEqual(seen, messages)

    async def test_api_stream_is_forwarded_immediately(self):
        seen = []
        start = {"type": "http.response.start", "status": 200,
                 "headers": [(b"content-type", b"text/event-stream")]}

        async def upstream(scope, receive, send):
            await send(start)
            self.assertEqual(seen, [start])
            await send({"type": "http.response.body", "body": b"data: fixture\n\n", "more_body": True})
            self.assertEqual(len(seen), 2)
            await send({"type": "http.response.body", "body": b"", "more_body": False})

        async def send(message):
            seen.append(message)

        await extension.DashboardScript(upstream)(
            {"type": "http", "method": "GET", "path": "/v1/responses"}, None, send)

    async def test_dashboard_cancellation_does_not_flush_partial_html(self):
        seen = []

        async def upstream(scope, receive, send):
            await send({"type": "http.response.start", "status": 200,
                        "headers": [(b"content-type", b"text/html")]})
            await send({"type": "http.response.body", "body": b"<body>partial", "more_body": True})
            raise asyncio.CancelledError

        async def send(message):
            seen.append(message)

        with self.assertRaises(asyncio.CancelledError):
            await extension.DashboardScript(upstream)(
                {"type": "http", "method": "GET", "path": "/dashboard"}, None, send)
        self.assertEqual(seen, [])


if __name__ == "__main__":
    unittest.main()
