# PitStop

Smart driver's journal and contextual car memory for your vehicle.

**Project state:** Active — see [`PROJECT_STATUS.md`](PROJECT_STATUS.md).  
**Next task:** DOM-003 — capture domain and confirmation policy tests.  
**Legacy tab-bar spike:** branch [`legacy/spike`](https://github.com/vil4engineering/pitstop-ios/tree/legacy/spike).

## Intended product

Save a thought about the car, find it when needed, record what actually happened,
and understand what matters next. **Notes** hold thoughts and intentions;
**History** holds recorded events; **Service** calculates maintenance state;
**Road** shows eligible milestones. **Car Board** brings their summaries together.

**Remember** is the shared capture capability: preserve a raw thought without AI
or use optional interpretation to propose structured data. **Pit** helps with
capture and clarification; it is not navigation or the product itself.

These are [product contracts](docs/requirements/product-charter.md#product-loop-and-feature-responsibilities),
not a shipped feature list. The current app is a scaffold; see the
[implementation inventory](docs/engineering/domain-inventory.md).

## Distribution

- **Org:** [vil4engineering](https://github.com/vil4engineering) · **Repo:** [vil4engineering/pitstop-ios](https://github.com/vil4engineering/pitstop-ios)
- **Bundle ID:** `dev.vil4max.pitstop` (new App Store listing; not an update from `dev.vilchevskyi.arteon`)
- **SwiftData:** no automatic migration between bundle IDs; fresh install or manual re-import
- **Notifications:** permission must be granted again on the new bundle
- **iCloud (future):** `iCloud.dev.vil4max.pitstop`

## Stack

iOS 27+ · Xcode 27+ · Swift 6 language mode · SwiftUI · SwiftData · Foundation Models · UserNotifications · Swift Testing + XCTest · en / uk / ru · MVVM

Product and engineering docs: [`docs/`](docs/README.md)

## Agent development loop

Start an authorized task with: **Run the agent loop for TASK-ID**. The agent
reads the owning specification, implements a bounded change, verifies it, and
delegates independent review using the host's available agent tools. The
[development workflow](docs/engineering/agent-loop-and-gitflow.md#agent-development-loop)
defines the handoff and evidence. Product work follows `PROJECT_STATUS.md`.

```sh
just doctor --json
just verify
```

The installed Runtime and shell executors are included in this repository;
verification does not need access to the private Kit repository. Host setup
instructions and project facts are in [`AGENTS.md`](AGENTS.md).

`just verify` is the local gate; GitHub Actions runs the shared Runtime tests
workflow on a self-hosted runner, and TestFlight builds are tag-gated
([ADR 0013](docs/decisions/0013-shared-ci-and-tag-gated-testflight.md)).
Record the command and result in the PR. The ruleset JSON remains a proposal
until applied in GitHub and does not require a hosted check. Documentation-only
edits do not require an app build. Local verification does not prove independent
review, release, or production AI capability.
