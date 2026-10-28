"""Apply the reviewed settings-origin fix to the pinned Headroom installation."""

from datetime import datetime, timezone
import hashlib
from importlib.metadata import version
from importlib.util import find_spec
from pathlib import Path
import shutil
import subprocess


EXPECTED_SHA256 = {
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
}
PATCH = Path(__file__).resolve().parents[1] / (
    "agent-setup/context-tools/patches/headroom-0.42.0-settings-origin.patch"
)


def main():
    if version("headroom-ai") != "0.42.0":
        raise SystemExit("This fix requires Headroom 0.42.0; review it before upgrading.")
    package = find_spec("headroom")
    if package is None or package.origin is None:
        raise SystemExit("Run this script with the installed Headroom Python interpreter.")
    root = Path(package.origin).parent
    originals = {name: (root / name).read_bytes() for name in EXPECTED_SHA256}
    digests = {name: hashlib.sha256(body).hexdigest() for name, body in originals.items()}
    if all(digests[name] == hashes[1] for name, hashes in EXPECTED_SHA256.items()):
        print("Headroom settings fix is already applied.")
        return
    if any(digests[name] != hashes[0] for name, hashes in EXPECTED_SHA256.items()):
        raise SystemExit("Headroom source differs from the reviewed file; no changes made.")
    command = ["patch", "--batch", "-p1", "-d", str(root.parent), "-i", str(PATCH)]
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
        subprocess.run(command, check=True)
        if any(
            hashlib.sha256((root / name).read_bytes()).hexdigest() != hashes[1]
            for name, hashes in EXPECTED_SHA256.items()
        ):
            raise RuntimeError("Patched source failed verification.")
    except BaseException:
        for name, original in originals.items():
            (root / name).write_bytes(original)
        raise
    print(f"Headroom settings fix applied. Backup: {backup}")


if __name__ == "__main__":
    main()
