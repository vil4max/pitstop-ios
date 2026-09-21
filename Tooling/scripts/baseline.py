#!/usr/bin/env python3
"""Check an app against the shared iOS baseline (docs/ci.md, "Baseline").

Usage: baseline.py <app-root> [--runtime <runtime-root>] [--strict]

Every app on this Runtime shares one baseline so the apps cannot drift apart
(owner decision, 2026-09-21). Within a day three apps had three pipelines, a
template fixed in one never reached the others, and a copied workflow went
stale the next time its template changed.

Errors (fail `just verify` in an app that set `pipeline: shared`):
  - .github/workflows/tests.yml and testflight.yml differ from the Runtime templates
  - ci_scripts/ci_post_clone.sh next to the project differs from its template
  - Tooling/runtime.yml names a bare, machine-shared simulator or lacks the
    baseline simulator.device_type / simulator.os
  - MARKETING_VERSION is not MAJOR.MINOR.PATCH in every configuration
Warnings (errors only with --strict):
  - the app has not opted in (`pipeline: shared`)
  - the installed Runtime is not the Runtime checkout's committed content
  - Tooling/.swiftlint.yml or .swiftformat differ from the Runtime templates
  - other workflows exist next to the two shared ones
"""

from __future__ import annotations

import filecmp
import re
import subprocess
import sys
from pathlib import Path

BASE_SIMULATOR = {"device_type": "iPhone 17", "os": "27.0"}


def runtime_yml_value(text: str, section: str, key: str) -> str | None:
    """Reads `section: / key: value` from a flat two-level YAML without a parser dependency."""
    inside = False
    for line in text.splitlines():
        if re.match(rf"^{section}:\s*$", line):
            inside = True
            continue
        if inside and re.match(r"^\S", line):
            inside = False
        if inside:
            match = re.match(rf"^\s+{key}:\s*(.*?)\s*(#.*)?$", line)
            if match:
                return match.group(1).strip().strip("\"'")
    return None


def top_value(text: str, key: str) -> str | None:
    match = re.search(rf"^{key}:\s*(.*?)\s*(#.*)?$", text, re.MULTILINE)
    return match.group(1).strip().strip("\"'") if match else None


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0].startswith("-"):
        sys.exit(__doc__)
    app = Path(args[0]).resolve()
    strict = "--strict" in args
    runtime = Path(args[args.index("--runtime") + 1]).resolve() if "--runtime" in args else None
    tooling = app / "Tooling"
    templates = tooling / "templates"
    errors: list[str] = []
    warnings: list[str] = []

    config = (tooling / "runtime.yml").read_text() if (tooling / "runtime.yml").is_file() else ""
    shared = top_value(config, "pipeline") == "shared"
    if not shared:
        warnings.append("not on the shared pipeline: add `pipeline: shared` to Tooling/runtime.yml")

    pipeline_issues: list[str] = []
    for name in ("tests.yml", "testflight.yml"):
        copy, template = app / ".github/workflows" / name, templates / "github" / name
        if not template.is_file():
            pipeline_issues.append(f"Tooling/templates/github/{name} is not installed; run `just harness-update`")
        elif not copy.is_file():
            pipeline_issues.append(f".github/workflows/{name} is missing")
        elif not filecmp.cmp(copy, template, shallow=False):
            pipeline_issues.append(f".github/workflows/{name} differs from Tooling/templates/github/{name}")
    workflows = app / ".github/workflows"
    extra = sorted(p.name for p in workflows.glob("*.y*ml") if p.name not in ("tests.yml", "testflight.yml")) if workflows.is_dir() else []
    if extra:
        warnings.append("other workflows next to the shared ones: " + ", ".join(extra))

    projects = [p for p in app.rglob("*.xcodeproj") if not {".claude", "Tooling", "Pods", "build", "DerivedData"} & set(p.relative_to(app).parts)]
    post_clones = [p.parent / "ci_scripts/ci_post_clone.sh" for p in projects]
    if not any(p.is_file() for p in post_clones):
        pipeline_issues.append("ci_scripts/ci_post_clone.sh next to the project is missing")
    post_clone_template = templates / "ci_post_clone.sh"
    if not post_clone_template.is_file():
        pipeline_issues.append("Tooling/templates/ci_post_clone.sh is not installed; run `just harness-update`")
    for script in (p for p in post_clones if p.is_file() and post_clone_template.is_file()):
        if not filecmp.cmp(script, post_clone_template, shallow=False):
            pipeline_issues.append(f"{script.relative_to(app)} differs from Tooling/templates/ci_post_clone.sh")
    (errors if shared else warnings).extend(pipeline_issues)

    name = runtime_yml_value(config, "simulator", "name")
    # Per-app names start with the scheme ("Pitstop iPhone 17"); a name that starts
    # with the device family is the device every project on the Mac shares.
    if name and re.match(r"(iPhone|iPad)\b", name):
        errors.append(f"simulator.name '{name}' is a machine-shared device; use simulator.device_type instead")
    for key, value in BASE_SIMULATOR.items():
        actual = runtime_yml_value(config, "simulator", key)
        if actual != value:
            errors.append(f"simulator.{key} is {actual!r}, baseline is {value!r}")

    versions: set[str] = set()
    for project in projects:
        pbxproj = project / "project.pbxproj"
        if pbxproj.is_file():
            versions |= set(re.findall(r"MARKETING_VERSION = ([^;]+);", pbxproj.read_text()))
    bad = sorted(v for v in versions if not re.fullmatch(r"\d+\.\d+\.\d+", v))
    if bad:
        errors.append("MARKETING_VERSION is not MAJOR.MINOR.PATCH: " + ", ".join(bad))
    if len(versions) > 1:
        errors.append("MARKETING_VERSION differs across configurations: " + ", ".join(sorted(versions)))

    if runtime and (runtime / "scripts/runtime-lock.sh").is_file():
        latest = subprocess.run([str(runtime / "scripts/runtime-lock.sh"), str(runtime)], capture_output=True, text=True).stdout.strip()
        installed = (tooling / ".runtime-lock").read_text().strip() if (tooling / ".runtime-lock").is_file() else ""
        if latest and installed != latest:
            head = subprocess.run(["git", "-C", str(runtime), "log", "-1", "--format=%h %s"], capture_output=True, text=True).stdout.strip()
            warnings.append(f"installed Runtime {installed[:10] or 'unknown'} is not the Runtime checkout ({head}); run `just harness-update`")

    # Style files are app-owned and not installed as templates, so they can only be
    # compared where the Runtime checkout is available.
    if runtime:
        for app_name, template_name in ((".swiftlint.yml", "swiftlint.yml"), (".swiftformat", "swiftformat")):
            copy, template = tooling / app_name, runtime / "templates" / template_name
            if copy.is_file() and template.is_file() and not filecmp.cmp(copy, template, shallow=False):
                warnings.append(f"Tooling/{app_name} differs from the Runtime template")

    for line in errors:
        print(f"baseline error    {line}")
    for line in warnings:
        print(f"baseline warning  {line}")
    failed = bool(errors) or (strict and bool(warnings))
    print(f"baseline: {'FAILED' if failed else 'OK'} ({len(errors)} error(s), {len(warnings)} warning(s))")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
