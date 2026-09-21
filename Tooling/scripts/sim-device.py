#!/usr/bin/env python3
"""Resolve, create or clean up an app's own simulators.

Every app gets devices named after itself ("<Scheme> iPhone 17" for runs and
screenshots, "<Scheme> iPhone 17 Tests" for tests), created on demand from the
configured device type and runtime. A bare device name such as "iPhone 17" is
shared by every project on the Mac: one project's test run shut down or took over
another's device, a test run detached the owner's live panel from the device a UI
session showed, and killed runs left clones of the shared device behind.

  sim-device.py resolve <name> <device-type> <os> <reserved-udid>
      prints the UDID of <name>, creating it when missing; a reserved UDID wins
      and must exist
  sim-device.py clean <name>...
      deletes shut-down "Clone N of <name>" devices left by earlier test runs
  sim-device.py prune <base> [<live-worktree>...]
      deletes shut-down "<base> · <worktree>" devices whose worktree is gone
"""

from __future__ import annotations

import json
import re
import subprocess
import sys


def simctl(*args: str, device_set: str | None = None) -> str:
    command = ["xcrun", "simctl"]
    if device_set:
        command += ["--set", device_set]
    return subprocess.run(command + list(args), check=True, capture_output=True, text=True).stdout


# Exit status 2 means "no simulator tooling here" (a stubbed or non-macOS
# environment); callers may fall back to a device name. Any other failure is real.
NO_SIMCTL = 2


def listing(kind: str, device_set: str | None = None) -> dict:
    try:
        # A real simctl always answers with a JSON object; empty output is a stub.
        return json.loads(simctl("list", kind, "-j", device_set=device_set))
    except (OSError, subprocess.CalledProcessError, ValueError):
        print(f"sim-device: simctl list {kind} unavailable", file=sys.stderr)
        sys.exit(NO_SIMCTL)


def runtime_id(os_version: str) -> str:
    runtimes = [
        r for r in listing("runtimes").get("runtimes", [])
        if r.get("platform", "iOS") == "iOS" and r.get("isAvailable", True)
    ]
    if os_version:
        wanted = "iOS-" + os_version.replace(".", "-")
        for runtime in runtimes:
            if runtime.get("identifier", "").endswith(wanted):
                return runtime["identifier"]
        sys.exit(f"no available iOS {os_version} simulator runtime; install it in Xcode > Settings > Components")
    if not runtimes:
        sys.exit("no available iOS simulator runtime")
    newest = max(runtimes, key=lambda r: [int(p) for p in re.findall(r"\d+", r.get("version", "0"))])
    return newest["identifier"]


def resolve(name: str, device_type: str, os_version: str, reserved: str) -> None:
    groups = listing("devices").get("devices", {})
    devices = [
        (runtime, device) for runtime, group in groups.items() for device in group
        if device.get("isAvailable", True)
    ]
    if reserved:
        if any(device["udid"] == reserved for _, device in devices):
            print(reserved)
            return
        sys.exit(f"simulator.udid {reserved} is not an available device; create it or fix Tooling/runtime.local.yml")
    suffix = "iOS-" + os_version.replace(".", "-") if os_version else ""
    for runtime, device in devices:
        if device.get("name") == name and (not suffix or runtime.endswith(suffix)):
            print(device["udid"])
            return
    udid = simctl("create", name, device_type, runtime_id(os_version)).strip()
    print(f"sim-device: created '{name}' ({device_type}) as {udid}", file=sys.stderr)
    print(udid)


def clean(names: list[str]) -> None:
    removed = 0
    # xcodebuild keeps test clones in the "testing" device set; older runs left them in the default set.
    for device_set in ("testing", None):
        groups = listing("devices", device_set).get("devices", {})
        for group in groups.values():
            for device in group:
                source = re.match(r"^Clone \d+ of (.+)$", device.get("name", ""))
                if source and source.group(1) in names and device.get("state") == "Shutdown":
                    simctl("delete", device["udid"], device_set=device_set)
                    removed += 1
    print(f"sim-device: removed {removed} leftover clone(s) of {', '.join(names)}")


def prune(base: str, live: list[str]) -> None:
    removed = 0
    prefix = base + " · "
    for group in listing("devices").get("devices", {}).values():
        for device in group:
            name = device.get("name", "")
            if name.startswith(prefix) and name[len(prefix):] not in live and device.get("state") == "Shutdown":
                simctl("delete", device["udid"])
                removed += 1
    print(f"sim-device: removed {removed} test device(s) of worktrees that no longer exist")


def main() -> None:
    if len(sys.argv) >= 2 and sys.argv[1] == "resolve" and len(sys.argv) == 6:
        resolve(*sys.argv[2:6])
    elif len(sys.argv) >= 3 and sys.argv[1] == "clean":
        clean(sys.argv[2:])
    elif len(sys.argv) >= 3 and sys.argv[1] == "prune":
        prune(sys.argv[2], sys.argv[3:])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
