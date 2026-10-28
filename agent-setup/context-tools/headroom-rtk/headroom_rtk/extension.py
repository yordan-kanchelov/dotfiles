"""Read RTK's native aggregate export without changing Headroom's accounting."""

import asyncio
from contextlib import suppress
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import shutil
from time import monotonic

from fastapi import Depends
from headroom.proxy.loopback_guard import require_loopback, require_same_origin
from starlette.responses import FileResponse, JSONResponse


CACHE_SECONDS = 15
TIMEOUT_SECONDS = 3
MAX_OUTPUT_BYTES = 1024 * 1024
MAX_DASHBOARD_BYTES = 1024 * 1024
MAX_DASHBOARD_CHUNKS = 1024
COUNTERS = ("total_commands", "total_input", "total_output", "total_saved")
SCRIPT = b'<script defer src="/dotfiles/rtk/panel.js"></script>'


def _result(summary=None, reason=None):
    result = {
        "available": summary is not None,
        "summary": summary,
        "scope": "retained_history",
        "coverage": ["claude", "codex"],
        "units": "estimated_tokens_bytes_div_4",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    if reason:
        result["reason"] = reason
    return result


def _summary(data):
    source = data.get("summary") if isinstance(data, dict) else None
    if not isinstance(source, dict):
        raise ValueError("invalid summary")
    result = {}
    for key in COUNTERS:
        value = source.get(key)
        if type(value) is not int or value < 0 or value > 2**53 - 1:
            raise ValueError("invalid counter")
        result[key] = value
    percent = source.get("avg_savings_pct")
    if type(percent) not in (int, float) or not math.isfinite(percent) or not 0 <= percent <= 100:
        raise ValueError("invalid percentage")
    result["avg_savings_pct"] = percent
    return result


def _find_rtk():
    found = shutil.which("rtk")
    if found:
        return found
    # launchd does not inherit the interactive shell's Homebrew PATH.
    for path in (Path("/opt/homebrew/bin/rtk"), Path("/usr/local/bin/rtk"),
                 Path("/home/linuxbrew/.linuxbrew/bin/rtk"), Path.home() / ".linuxbrew/bin/rtk"):
        if path.is_file() and os.access(path, os.X_OK):
            return str(path)
    return None


async def _collect():
    binary = _find_rtk()
    if binary is None:
        return _result(reason="not_installed")
    process = None
    try:
        async with asyncio.timeout(TIMEOUT_SECONDS):
            process = await asyncio.create_subprocess_exec(
                binary, "gain", "--all", "--format", "json",
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
                env={**os.environ, "RTK_TELEMETRY_DISABLED": "1", "RTK_ONRAMP_DISABLED": "1"},
            )
            output = bytearray()
            while chunk := await process.stdout.read(65536):
                output.extend(chunk)
                if len(output) > MAX_OUTPUT_BYTES:
                    return _result(reason="invalid_data")
            await process.wait()
            if process.returncode:
                return _result(reason="command_failed")
        return _result(summary=_summary(json.loads(output)))
    except TimeoutError:
        return _result(reason="timeout")
    except (ValueError, UnicodeDecodeError, OverflowError):
        return _result(reason="invalid_data")
    except FileNotFoundError:
        return _result(reason="not_installed")
    except OSError:
        return _result(reason="command_failed")
    finally:
        if process is not None and process.returncode is None:
            with suppress(ProcessLookupError):
                process.kill()
            with suppress(TimeoutError):
                await asyncio.wait_for(process.wait(), 1)


class StatsCache:
    def __init__(self):
        self.value = None
        self.expires_at = 0
        self.lock = asyncio.Lock()

    async def get(self):
        if self.value is not None and monotonic() < self.expires_at:
            return self.value
        async with self.lock:
            if self.value is None or monotonic() >= self.expires_at:
                self.value = await _collect()
                self.expires_at = monotonic() + CACHE_SECONDS
            return self.value


class DashboardScript:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope["method"] != "GET" or scope["path"] != "/dashboard":
            return await self.app(scope, receive, send)
        start = None
        chunks = []
        buffered_bytes = 0

        async def inject(message):
            nonlocal start, buffered_bytes
            if message["type"] == "http.response.start":
                headers = dict(message.get("headers", []))
                if (message["status"] == 200
                        and headers.get(b"content-type", b"").lower().startswith(b"text/html")
                        and headers.get(b"content-encoding", b"identity") == b"identity"):
                    start = {**message, "headers": list(message.get("headers", []))}
                    return
            elif start is not None and message["type"] == "http.response.body":
                body = message.get("body", b"")
                if (buffered_bytes + len(body) > MAX_DASHBOARD_BYTES
                        or len(chunks) >= MAX_DASHBOARD_CHUNKS):
                    await send(start)
                    for chunk in chunks:
                        await send(chunk)
                    chunks.clear()
                    start = None
                    await send(message)
                    return
                chunks.append(dict(message))
                buffered_bytes += len(body)
                if message.get("more_body", False):
                    return
                body = b"".join(chunk.get("body", b"") for chunk in chunks)
                position = body.lower().rfind(b"</body>")
                if position >= 0 and SCRIPT not in body:
                    body = body[:position] + SCRIPT + body[position:]
                    headers = [(key, value) for key, value in start["headers"]
                               if key.lower() not in {b"content-length", b"etag", b"content-md5", b"digest"}]
                    headers.append((b"content-length", str(len(body)).encode()))
                    await send({**start, "headers": headers})
                    await send({**message, "body": body})
                else:
                    await send(start)
                    for chunk in chunks:
                        await send(chunk)
                chunks.clear()
                start = None
                return
            await send(message)

        await self.app(scope, receive, inject)


def install(app, config):
    cache = StatsCache()

    @app.get("/dotfiles/rtk/stats", dependencies=[Depends(require_loopback), Depends(require_same_origin)])
    async def stats():
        return JSONResponse(await cache.get(), headers={"Cache-Control": "no-store"})

    @app.get("/dotfiles/rtk/panel.js", dependencies=[Depends(require_loopback), Depends(require_same_origin)])
    async def panel():
        return FileResponse(Path(__file__).with_name("panel.js"), media_type="application/javascript",
                            headers={"Cache-Control": "no-cache"})

    app.add_middleware(DashboardScript)
