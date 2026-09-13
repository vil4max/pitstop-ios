# PitStop

Smart driver's journal and contextual car memory for your vehicle.

**Project state:** Frozen — see [`PROJECT_STATUS.md`](PROJECT_STATUS.md).  
**Resume next task (when unfrozen):** DOM-002 — spec-derived domain test fixtures.  
**Legacy tab-bar spike:** branch [`legacy/spike`](https://github.com/vil4engineering/pitstop-ios/tree/legacy/spike).

## Distribution

- **Org:** [vil4engineering](https://github.com/vil4engineering) · **Repo:** [vil4engineering/pitstop-ios](https://github.com/vil4engineering/pitstop-ios)
- **Bundle ID:** `dev.vil4max.pitstop` (new App Store listing; not an update from `dev.vilchevskyi.arteon`)
- **SwiftData:** no automatic migration between bundle IDs; fresh install or manual re-import
- **Notifications:** permission must be granted again on the new bundle
- **iCloud (future):** `iCloud.dev.vil4max.pitstop`

## Stack

iOS 26+ · Xcode 26+ · SwiftUI · SwiftData · Foundation Models · UserNotifications · Swift Testing + XCTest · en / uk / ru · MVVM

Product and engineering specs: [`specs/`](specs/)

## Agent development loop

Start an authorized task with: **Run the agent loop for TASK-ID**. The agent
reads the owning specification, implements a bounded change, verifies it, and
delegates independent review using the host's available agent tools. The
[development workflow](specs/24_PROJECT_MANAGEMENT_AND_GITFLOW.md#agent-development-loop)
defines the handoff and evidence. Product work follows `PROJECT_STATUS.md`;
the infrastructure setup exception does not unfreeze features.

```sh
just doctor --json
just verify
```

The installed Runtime and shell executors are included in this repository;
verification does not need access to the private Kit repository. Host setup
instructions and project facts are in [`AGENTS.md`](AGENTS.md).

PR CI runs `just verify-ci` on macOS 26 with Xcode 26.6 and preserves logs and
test results. The workflow becomes active after publication; the ruleset JSON
is a configuration proposal until applied in GitHub. A passing local gate does
not prove CI, independent review, release, or production AI capability.
