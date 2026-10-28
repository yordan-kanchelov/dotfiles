"""Apply the reviewed fixes to the pinned Headroom installation."""

from datetime import datetime, timezone
import hashlib
from importlib.metadata import version
from importlib.util import find_spec
from pathlib import Path
import shutil
import subprocess


FIXES = {
    "headroom-0.42.0-settings-origin.patch": {
        "settings_store.py": (
            "3f4a7bf8a994bd22dc56d480a54ea8fc4c9321073a36827674d411d64440d7d0",
            "141c3351b6eb7e9d56e86ef7417eef7ebf1641939983a85aefc41eb640ec8af3",
        ),
        "install/runtime.py": (
            "3eaefaba73841cc9c441ab00bcb0d355c71184dd87f14d3063f1826f1727ce9c",
            "f6c1bebf3faf1e658acb83ffcbfe1489e75f5dbb7a22fd6f81a7beae19ded240",
        ),
        "cli/proxy.py": (
            "4ec4a769d59d30edf0264b7c1afda37199a3c9dd5f85b68e823d18095efc1fd6",
            "6f0aa1ed1ec543ceac67b76eb38ea3dbfb43cf4e663d6d747cc1b778a4dc4ece",
        ),
    },
    "headroom-0.42.0-transformations-ui.patch": {
        "dashboard/templates/dashboard.html": (
            "0c4b3c2f702a0ffd7599f9e4e8eb6c29ceeb5ba472e12d801bb980b50dbcb6ed",
            "c0ff38bdd2e5a5515ec06e07dd266df7243462220b3c25bc9cd9b6286bcf6756",
        ),
    },
    "headroom-0.42.0-transformations-capture.patch": {
        "proxy/outcome.py": (
            "403224d5a3a1c9839f89be914fea73db0ba1caa9d04e373288302746083d6821",
            "f102c253d79244cfeaffa81bcee65be69030a0e2040aaf7f1521f3cc02880875",
        ),
        "proxy/handlers/openai.py": (
            "98194dcf5b10f4a4a5ca65dc0bd5f3145e0de8b29c2cbb59ebed94cbcd50c241",
            "4d3d177747a232113ce1b14c2fa975caae90a4f6bf94de30a3be4474f7fe15f2",
        ),
        "proxy/handlers/streaming.py": (
            "9b0062589cc865a1dc9c00a8c11a31e9fce7691d9bef1da030b77c875e3a001d",
            "a3c8db880bde939e25ad5684169f3b77212320bd54acdf78eb8d5bdabb2c4b82",
        ),
        "proxy/server.py": (
            "8f1282daf075e4cfac23fc811d52a3d50cd00e34b5c59767d2f488f4382680c4",
            "a57a213eea2550b471fc8fc1026dfe5cc71e50c7cc5c89d9485664905de67e11",
        ),
    },
}
PATCH_DIR = Path(__file__).resolve().parents[1] / "agent-setup/context-tools/patches"


def main():
    if version("headroom-ai") != "0.42.0":
        raise SystemExit("These fixes require Headroom 0.42.0; review them before upgrading.")
    package = find_spec("headroom")
    if package is None or package.origin is None:
        raise SystemExit("Run this script with the installed Headroom Python interpreter.")
    root = Path(package.origin).parent
    pending = []
    expected = {}
    for patch_name, files in FIXES.items():
        digests = {name: hashlib.sha256((root / name).read_bytes()).hexdigest() for name in files}
        if all(digests[name] == hashes[1] for name, hashes in files.items()):
            continue
        if any(digests[name] != hashes[0] for name, hashes in files.items()):
            raise SystemExit("Headroom source differs from the reviewed files; no changes made.")
        pending.append(patch_name)
        expected.update(files)
    if not pending:
        print("Headroom fixes are already applied.")
        return
    originals = {name: (root / name).read_bytes() for name in expected}
    commands = [
        ["patch", "--batch", "-p1", "-d", str(root.parent), "-i", str(PATCH_DIR / name)]
        for name in pending
    ]
    for command in commands:
        subprocess.run([*command, "--dry-run"], check=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    backup = Path.home() / ".local/state/dotfiles-context-tools/backups" / stamp
    backup.mkdir(parents=True, mode=0o700)
    for name in originals:
        saved = backup / name
        saved.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        shutil.copy2(root / name, saved)
        saved.chmod(0o600)
    try:
        for command in commands:
            subprocess.run(command, check=True)
        if any(
            hashlib.sha256((root / name).read_bytes()).hexdigest() != hashes[1]
            for name, hashes in expected.items()
        ):
            raise RuntimeError("Patched source failed verification.")
    except BaseException:
        for name, original in originals.items():
            (root / name).write_bytes(original)
        raise
    print(f"Headroom fixes applied. Backup: {backup}")


if __name__ == "__main__":
    main()
