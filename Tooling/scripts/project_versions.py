#!/usr/bin/env python3
"""Read MARKETING_VERSION values from an Xcode project file in either format.

Usage: project_versions.py [FILE]    (stdin when FILE is omitted)
Prints the distinct values, one per line, sorted.

Xcode 27.2 adds a JSON project format, `project.xcproj`, next to the property
list `project.pbxproj` (Xcode 27.2 release notes, "Project Format"). In JSON a
build setting is a key in a `build-settings` object, and a value that differs by
configuration carries a condition suffix: `"MARKETING_VERSION[config=Release]"`.
The Runtime reads versions for tf-check, tf-promote and the baseline, so both
formats must give the same answer; the format is detected from the content, not
the file name, because callers pass `git show` output on stdin.
"""

from __future__ import annotations

import json
import re
import sys
from typing import Iterator

SETTING = re.compile(r"^MARKETING_VERSION(\[[^\]]*\])?$")


def _walk(node: object) -> Iterator[str]:
    if isinstance(node, dict):
        for key, value in node.items():
            if isinstance(key, str) and SETTING.match(key) and isinstance(value, (str, int, float)):
                yield str(value)
            else:
                yield from _walk(value)
    elif isinstance(node, list):
        for item in node:
            yield from _walk(item)


def _relaxed_json(text: str) -> str:
    """Drops comments and trailing commas outside strings. Xcode 27.2 writes
    project.xcproj with a comma after every last element (`"Release",` before
    `]`), which strict JSON rejects; a first version of this reader parsed
    strictly and silently found no version in a real converted project."""
    out: list[str] = []
    i, n, in_string = 0, len(text), False
    while i < n:
        c = text[i]
        if in_string:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 1
            elif c == '"':
                in_string = False
        elif c == '"':
            in_string = True
            out.append(c)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        elif c == ",":
            j = i + 1
            while j < n and text[j] in " \t\r\n":
                j += 1
            if j < n and text[j] in "]}":
                i += 1
                continue
            out.append(c)
        else:
            out.append(c)
        i += 1
    return "".join(out)


def marketing_versions(text: str) -> set[str]:
    stripped = text.lstrip()
    if stripped.startswith("{"):
        try:
            return {value.strip() for value in _walk(json.loads(_relaxed_json(text)))}
        except ValueError:
            pass
    return {value.strip().strip('"') for value in re.findall(r"MARKETING_VERSION = ([^;]+);", text)}


def main() -> int:
    text = open(sys.argv[1], encoding="utf-8").read() if len(sys.argv) > 1 else sys.stdin.read()
    for version in sorted(marketing_versions(text)):
        print(version)
    return 0


if __name__ == "__main__":
    sys.exit(main())
