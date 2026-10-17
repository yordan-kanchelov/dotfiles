#!/usr/bin/env python3
"""Reject injected fact aliases in the scoped playbooks (requires PyYAML).

Run with the controller's Python: python3 scripts/test-ansible-facts.py
This is a static regression: it never executes provisioning tasks.
"""

from collections import Counter
import json
from pathlib import Path
import re
import sys

import yaml


# Gathered facts, not connection settings, magic variables, or registered results.
FACT_NAMES = frozenset({
    "architecture", "date_time", "distribution", "distribution_release",
    "distribution_version", "env", "kernel", "os_family", "service_mgr",
    "system", "user_gid", "user_id",
})
ALIASES = re.compile(r"\bansible_(?:" + "|".join(sorted(FACT_NAMES)) + r")\b")
DOT_FACTS = re.compile(r"\bansible_facts\s*\.")
BRACKET_FACTS = re.compile(r"\bansible_facts\s*\[\s*['\"]([^'\"]+)['\"]\s*\]")


def scalars(node):
    if isinstance(node, yaml.ScalarNode):
        yield node
    elif isinstance(node, yaml.SequenceNode):
        for child in node.value:
            yield from scalars(child)
    elif isinstance(node, yaml.MappingNode):
        for key, value in node.value:
            yield from scalars(key)
            yield from scalars(value)


def audit(text):
    failures = []
    facts = Counter()
    for document in yaml.compose_all(text):
        for node in scalars(document):
            for pattern in (ALIASES, DOT_FACTS):
                for match in pattern.finditer(node.value):
                    failures.append((node.start_mark.line + 1, match.group()))
            facts.update(BRACKET_FACTS.findall(node.value))
    return failures, facts


def main():
    # Prove the scanner rejects every audited alias and dot-style fact access,
    # but accepts ordinary Ansible settings/magic variables/registered results.
    for name in sorted(FACT_NAMES):
        assert audit("value: '{{ ansible_" + name + " }}'\n")[0], name
        assert not audit('value: "{{ ansible_facts[\'' + name + '\'] }}"\n')[0], name
    assert audit("when: ansible_facts.packages is defined\n")[0]
    assert not audit("""
vars:
  ansible_become_exe: /usr/bin/sudo.ws
when: ansible_check_mode and ansible_loop_var is defined
register: windows_agents
changed_when: windows_agents.stdout is defined
# ansible_env is mentioned only in a comment.
""")[0]

    root = Path(__file__).resolve().parents[1]
    paths = sorted([
        root / "setup.yml", root / "windows.yml", root / ".github/sudo-compat.yml",
        *root.glob("tasks/*.yml"), *root.glob("vars/*.yml"),
    ])
    failures = []
    facts = Counter()
    for path in paths:
        issues, counts = audit(path.read_text(encoding="utf-8"))
        failures.extend(f"{path.relative_to(root).as_posix()}:{line}: {token}"
                        for line, token in issues)
        facts.update(counts)
    print(json.dumps({
        "files_scanned": len(paths),
        "scope": [p.relative_to(root).as_posix() for p in paths],
        "deprecated_or_dot_references": len(failures),
        "bracket_fact_references": dict(sorted(facts.items())),
        "bracket_fact_reference_count": sum(facts.values()),
        "scanner_cases_passed": len(FACT_NAMES) * 2 + 2,
    }, indent=2))
    for failure in failures:
        print(failure, file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
