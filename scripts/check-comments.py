#!/usr/bin/env python3
import argparse
import io
import json
import re
import subprocess
import sys
import tokenize
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASELINE = ROOT / "scripts" / "comment-baseline.json"

EXCLUDED_PREFIXES = (".config/ghostty/themes/",)
EXCLUDED_NAMES = {"LICENSE", "lazy-lock.json"}
EXCLUDED_PATHS = {"files/secrets.template"}

DIRECTIVES = re.compile(
    r"""^(
        \#!                                  |
        \#\s*shellcheck\s                    |
        \#\s*noqa\b                          |
        \#Requires\s                         |
        \#\s*(vim?|ex):                      |
        \#\s*-\*-                            |
        \#\s*yaml-language-server:           |
        \#\s*(type|pyright|mypy):            |
        ---\s*@                              |
        //\s*@ts-                            |
        ///\s*<reference                     |
        //\s*(eslint|biome-ignore|prettier-ignore)
    )""",
    re.VERBOSE,
)

SHELL_NAMES = {".zshrc", ".zshrc.core", ".zprofile", ".bashrc"}
HASH_NAMES = {".tmux.conf", "tmux.conf", ".xbindkeysrc", "Caddyfile", ".gitignore", ".gitattributes"}
HASH_SUFFIXES = {".toml", ".conf"}


def pinned_paths():
    paths = []
    for sources in sorted((ROOT / "agent-setup").glob("*/sources.json")):
        for component in json.loads(sources.read_text())["components"]:
            for artifact in component.get("artifacts", []):
                paths.append("agent-setup/" + artifact["path"].rstrip("/") + "/")
    return tuple(paths)


def tracked_files():
    out = subprocess.run(
        ["git", "ls-files", "-z"], cwd=ROOT, check=True, capture_output=True
    ).stdout.decode()
    pinned = pinned_paths()
    for rel in filter(None, out.split("\0")):
        if rel.startswith(pinned + EXCLUDED_PREFIXES):
            continue
        if Path(rel).name in EXCLUDED_NAMES or rel in EXCLUDED_PATHS:
            continue
        if (ROOT / rel).is_file() and not (ROOT / rel).is_symlink():
            yield rel


def language(rel, first_line):
    path = Path(rel)
    suffix = path.suffix.lower()
    if suffix == ".py" or first_line.startswith("#!") and "python" in first_line:
        return "python"
    if suffix in {".sh", ".bash", ".zsh"} or path.name in SHELL_NAMES:
        return "shell"
    if first_line.startswith("#!") and re.search(r"\b(ba|z|da)?sh\b", first_line):
        return "shell"
    if suffix in {".yml", ".yaml"}:
        return "yaml"
    if suffix in {".ps1", ".psm1"}:
        return "powershell"
    if suffix == ".lua":
        return "lua"
    if suffix in {".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx"}:
        return "c"
    if suffix in HASH_SUFFIXES or path.name in HASH_NAMES:
        return "hash"
    if rel == ".config/ghostty/config":
        return "hash"
    return None


def python_comments(text):
    found = set()
    try:
        for tok in tokenize.generate_tokens(io.StringIO(text).readline):
            if tok.type == tokenize.COMMENT:
                found.add((tok.start[0], tok.string))
    except (tokenize.TokenError, IndentationError, SyntaxError):
        return hash_comments(text, word_start=False)
    return sorted(found)


def hash_comments(text, word_start=False, heredocs=False):
    found = []
    quote = None
    heredoc = None
    word_breaks = " \t;&|"
    for lineno, line in enumerate(text.splitlines(), 1):
        if heredoc:
            if line.strip() == heredoc:
                heredoc = None
            elif line.lstrip().startswith("#") and not line.lstrip().startswith("#!"):
                found.append((lineno, line.strip()))
            continue
        breaks = word_breaks if word_start else " \t"
        code_end = len(line)
        i = 0
        while i < len(line):
            ch = line[i]
            if quote:
                if ch == "\\" and quote == '"':
                    i += 2
                    continue
                if ch == quote:
                    quote = None
            elif ch == "\\":
                i += 2
                continue
            elif ch in "'\"":
                quote = ch
            elif ch == "#" and (i == 0 or line[i - 1] in breaks):
                found.append((lineno, line[i:].strip()))
                code_end = i
                break
            i += 1
        if heredocs and not quote:
            match = re.search(r"(?<!<)<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1(?!<)", line[:code_end])
            if match:
                heredoc = match.group(2)
        if not word_start:
            quote = None
    return found


def yaml_comments(text):
    found = []
    for lineno, line in enumerate(text.splitlines(), 1):
        stripped = line.lstrip()
        if stripped.startswith("#"):
            found.append((lineno, stripped))
            continue
        quote = None
        for i, ch in enumerate(line):
            if quote:
                if ch == quote:
                    quote = None
            elif ch in "'\"" and (i == 0 or line[i - 1] in " \t:[{,-"):
                quote = ch
            elif ch == "#" and line[i - 1] in " \t":
                found.append((lineno, line[i:].strip()))
                break
    return found


def powershell_comments(text):
    found = []
    block = False
    here = None
    for lineno, line in enumerate(text.splitlines(), 1):
        if here:
            if line.startswith(here):
                here = None
            continue
        if block:
            found.append((lineno, line.strip()))
            if "#>" in line:
                block = False
            continue
        quote = None
        i = 0
        while i < len(line):
            ch = line[i]
            if quote:
                if ch == "`" and quote == '"':
                    i += 2
                    continue
                if ch == quote:
                    if i + 1 < len(line) and line[i + 1] == quote:
                        i += 2
                        continue
                    quote = None
            elif ch == "`":
                i += 2
                continue
            elif line.startswith("<#", i):
                found.append((lineno, line[i:].strip()))
                if "#>" not in line[i + 2 :]:
                    block = True
                break
            elif ch == "@" and line[i + 1 : i + 2] in ("'", '"') and line[i + 2 :].strip() == "":
                here = line[i + 1] + "@"
                break
            elif ch in "'\"":
                quote = ch
            elif ch == "#":
                found.append((lineno, line[i:].strip()))
                break
            i += 1
    return found


def dash_or_slash_comments(text, marker, block_open, block_close):
    found = []
    block = None
    for lineno, line in enumerate(text.splitlines(), 1):
        if block:
            found.append((lineno, line.strip()))
            if block in line:
                block = None
            continue
        quote = None
        i = 0
        while i < len(line):
            ch = line[i]
            if quote:
                if ch == "\\":
                    i += 2
                    continue
                if ch == quote:
                    quote = None
            elif ch in "'\"`":
                quote = ch
            elif line.startswith(marker, i):
                rest = line[i:]
                opened = block_open(rest)
                found.append((lineno, rest.strip()))
                if opened and opened not in rest[len(marker) :]:
                    block = opened
                break
            elif marker == "//" and line.startswith("/*", i):
                found.append((lineno, line[i:].strip()))
                if "*/" not in line[i + 2 :]:
                    block = "*/"
                break
            i += 1
    return found


def lua_block(rest):
    match = re.match(r"--\[(=*)\[", rest)
    return "]" + match.group(1) + "]" if match else None


def comments(rel):
    text = (ROOT / rel).read_text(encoding="utf-8", errors="replace")
    first = text.split("\n", 1)[0]
    lang = language(rel, first)
    if lang is None:
        return []
    if lang == "python":
        raw = python_comments(text)
    elif lang == "shell":
        raw = hash_comments(text, word_start=True, heredocs=True)
    elif lang == "yaml":
        raw = yaml_comments(text)
    elif lang == "powershell":
        raw = powershell_comments(text)
    elif lang == "lua":
        raw = dash_or_slash_comments(text, "--", lua_block, None)
    elif lang == "c":
        raw = dash_or_slash_comments(text, "//", lambda rest: None, None)
    else:
        raw = hash_comments(text)
    return [(n, c) for n, c in raw if not (DIRECTIVES.match(c) and (n == 1 or not c.startswith("#!")))]


def strip(rel, found):
    path = ROOT / rel
    lines = path.read_text(encoding="utf-8").split("\n")
    removed = set()
    for lineno, text in found:
        line = lines[lineno - 1]
        start = line.rfind(text)
        if line[:start].strip():
            lines[lineno - 1] = line[:start].rstrip()
        else:
            removed.add(lineno - 1)
    kept = []
    after_removal = False
    for index, line in enumerate(lines):
        if index in removed:
            after_removal = True
            continue
        blank = line.strip() == "" and index < len(lines) - 1
        top = len(kept) == 0 or (len(kept) == 1 and kept[0].startswith(("#!", "#Requires", "---")))
        if blank and after_removal and (top or kept[-1].strip() == ""):
            continue
        after_removal = False
        kept.append(line)
    path.write_text("\n".join(kept), encoding="utf-8")
    return len(lines) - len(kept)


def scan():
    result = {}
    for rel in tracked_files():
        found = comments(rel)
        if found:
            result[rel] = found
    return result


def load_baseline():
    if not BASELINE.exists():
        return {}
    return json.loads(BASELINE.read_text())


def write_baseline(counts):
    BASELINE.write_text(json.dumps(dict(sorted(counts.items())), indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Ratchet check: no file may gain comments; files that lose them must lower the baseline."
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--list", action="store_true", help="print every counted comment as path:line: text")
    mode.add_argument("--update", action="store_true", help="lower the baseline to the current counts")
    mode.add_argument("--init", action="store_true", help="write the baseline from scratch")
    mode.add_argument("--total", action="store_true", help="print the number of comment lines")
    mode.add_argument("--strip", action="store_true", help="delete every counted comment in the given paths")
    parser.add_argument("paths", nargs="*", help="limit --list or --total to these paths or directories")
    args = parser.parse_args()

    found = scan()
    if args.paths:
        prefixes = tuple(p.rstrip("/") for p in args.paths)
        found = {
            rel: c for rel, c in found.items()
            if any(rel == p or rel.startswith(p + "/") for p in prefixes)
        }
    counts = {rel: len(c) for rel, c in found.items()}

    if args.list:
        for rel, items in sorted(found.items()):
            for lineno, text in items:
                print(f"{rel}:{lineno}: {text}")
        return 0
    if args.strip:
        if not args.paths:
            parser.error("--strip needs at least one path")
        shed = sum(strip(rel, items) for rel, items in sorted(found.items()))
        print(f"Stripped {sum(counts.values())} comment lines from {len(counts)} files; {shed} lines removed.")
        return 0
    if args.total:
        print(sum(counts.values()))
        return 0
    if args.init:
        write_baseline(counts)
        print(f"Baseline written: {sum(counts.values())} comment lines in {len(counts)} files.")
        return 0

    baseline = load_baseline()
    grown = {rel: n for rel, n in counts.items() if n > baseline.get(rel, 0)}
    shrunk = {rel: n for rel, n in counts.items() if n < baseline.get(rel, 0)}
    shrunk.update({rel: 0 for rel in baseline if rel not in counts})

    if args.update:
        if grown:
            for rel, n in sorted(grown.items()):
                print(f"{rel}: {n} comment lines, baseline {baseline.get(rel, 0)}; --update only lowers counts")
            return 1
        lowered = {rel: n for rel, n in baseline.items() if rel in counts}
        lowered.update(counts)
        write_baseline({rel: n for rel, n in lowered.items() if n})
        print(f"Baseline lowered: {sum(counts.values())} comment lines in {len(counts)} files.")
        return 0

    status = 0
    for rel, n in sorted(grown.items()):
        status = 1
        print(f"{rel}: {n} comment lines, baseline allows {baseline.get(rel, 0)}. Comments are banned;")
        print("  move the reasoning into a commit message, docs/adr/, or clearer code:")
        for lineno, text in found[rel]:
            print(f"    {rel}:{lineno}: {text}")
    for rel, n in sorted(shrunk.items()):
        status = 1
        print(f"{rel}: {n} comment lines, baseline still allows {baseline[rel]}.")
        print("  Ratchet it down: python3 scripts/check-comments.py --update")
    if status == 0:
        print(f"Comment ratchet holds: {sum(counts.values())} comment lines in {len(counts)} files.")
    return status


if __name__ == "__main__":
    sys.exit(main())
