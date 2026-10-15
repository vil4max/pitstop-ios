# Backlog run (started 2026-10-15)

**Status:** in progress  
**Baseline:** `955b630` is frozen: never rewrite history before or at it.  
**Rule:** each group ends with `just verify` green and one commit; push after
the private-data scan.

## Scope

1. Make the gate green.
2. Verify the 2026-10-10 audit findings and fix the confirmed ones
   ([`audit-2026-10-10.md`](audit-2026-10-10.md)).
3. Work the documented backlog (`PROJECT_STATUS.md`, `docs/planning/`).

Out of scope without the owner: new requirements, App Store Connect,
releases, `v` and `tf-` tags.

## Groups

| # | Group | Findings | State |
|---|---|---|---|
| 1 | Gate: path-independent source test; widget read-only open refuses an older store without a Core Data migration attempt | baseline | done |
| 2 | Domain defects and guards | F1, F21, F4, F84, F22 | done |
| 3 | Feature defects | F24, F42, F46, F56, F58, F59 | done |
| 4 | Test-host isolation and composition-root tests | F47, F53, F75 | done |
| 5 | Lint warnings and file-length splits | F9, F15, F17, F25, F26, F27, F67, F76, F83 | done |
| 6 | Small debt: dead code, comments, catalog keys, missing tests | F2, F6, F8, F10, F16, F19, F23, F28, F29, F30, F37, F40, F41, F43, F44, F55, F60, F61, F66, F74, F77, F79, F80, F81, F85 | done |
| 7 | Duplication | F7, F31, F34, F35, F36, F45, F49, F50, F51, F57, F64, F71 (tests), F72, F73, F78, F86 | pending |
| 8 | Documentation backlog: roadmap and status refresh | SYS-007 status | pending |
| 9 | Move to the iOS plugin gate (owner decision 2026-10-15): `ios-verify.conf`, drop `Tooling/` and the justfile import, CI on Apple's tools, gate sections of `AGENTS.md`/`README.md`, `.worktreeinclude` | — | waits for the plugin rename |

## Waiting on the owner

- F3: ru/uk wording of the provisional car name.
- F2: recognising spelled-out units and `пробіг` in captures.
- F71: moving the photo decoder behind an injected protocol.
- SYS-008 (iPhone Duo layout hardening, 1.3.0): no requirement exists yet.
- MNT-INT-003: real market, source, budget and legal review.
- Product investigations (`investigations.md`) need beta evidence; runtime
  AI stays behind the ADR 0027 gate (`ai-roadmap.md`).
- Approving `Status: Proposed` requirements.
