#!/usr/bin/env python3
"""Add translated keys to Localizable.xcstrings without reformatting the catalog.

Usage: scripts/xcstrings_add.py strings.json
where strings.json is {"key": ["en", "ru", "uk"], ...}. Existing keys are replaced.
Output mimics Xcode's writer (" : " separators, case-insensitive key order, "{\n\n}" for
empty objects) so a merge shows only the added keys.
"""
import json
import re
import sys

CATALOG = "Pitstop/Resources/Localizations/Localizable.xcstrings"
LANGUAGES = ("en", "ru", "uk")


def main() -> None:
    catalog = json.load(open(CATALOG, encoding="utf-8"))
    for key, values in json.load(open(sys.argv[1], encoding="utf-8")).items():
        if len(values) != len(LANGUAGES):
            sys.exit(f"{key}: expected {len(LANGUAGES)} values ({', '.join(LANGUAGES)})")
        catalog["strings"][key] = {
            "localizations": {
                language: {"stringUnit": {"state": "translated", "value": value}}
                for language, value in zip(LANGUAGES, values)
            }
        }
    catalog["strings"] = dict(sorted(catalog["strings"].items(), key=lambda item: item[0].lower()))
    text = json.dumps(catalog, ensure_ascii=False, indent=2, separators=(",", " : "))
    text = re.sub(r"^( *)(.*) : \{\}", lambda m: f"{m.group(1)}{m.group(2)} : {{\n\n{m.group(1)}}}", text, flags=re.M)
    open(CATALOG, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    main()
