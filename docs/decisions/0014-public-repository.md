# Public Repository

**Status:** Accepted (owner decision, 2026-09-21)\
**Supersedes:** the self-hosted runner choice in
[`0013-shared-ci-and-tag-gated-testflight.md`](0013-shared-ci-and-tag-gated-testflight.md)

## Context

The repository was private, so its tests ran on a self-hosted runner on the
owner's Mac to avoid billed macOS minutes. The owner decided to make PitStop
public: GitHub-hosted runners are free for public repositories, and the
self-hosted runner then no longer has to be kept online.

The history could not simply be switched to public. Early commits used the
owner's real car as seed data, and planning documents carried personal notes.
A force-push does not remove those commits from GitHub: every pull request
keeps its original commits under `refs/pull/N/head`, and only GitHub Support
can delete those refs.

## Decision

- The old repository was renamed `pitstop-ios-archive`, kept private until the
  move was verified, then deleted at the owner's request. The full-history
  backup bundle made before the rewrite was also deleted by owner decision: no
  copy of the old history is kept.
- A new public `vil4max/pitstop-ios` was created from a rewritten history
  (`git filter-repo`), with only `main` and tags pushed. The rewrite:
  - removed the files that held real-vehicle seed data, the maintenance
    importer that embedded it, and the planning documents with personal notes;
  - replaced the owner's private literals and personal-planning wording in
    every remaining file version and commit message.
  The kit scan `private-data-scan.py --history` reported the rewritten history
  clean before the first push.
- The tests workflow runs on GitHub-hosted `xcode-27` runners: `IOS_RUNNER`
  stays unset and the template picks the hosted image for a public repository.
- The self-hosted runner was removed. A public repository must never have one:
  a pull request from a fork could run code on the owner's Mac.
- `AGENTS.md` declares the repository public, so the private-data scan applies
  to every push.

Commit hashes in older documents and ADRs refer to the archived history; the
rewritten commits keep their messages and order, minus the removed content.

## Rejected alternatives

- **Rewrite in place and ask GitHub Support to delete the pull request refs.**
  Days of waiting on a third party, and the repository could not go public
  until then.
- **Keep the repository private with the self-hosted runner.** CI would run
  only while the Mac is on, and the owner preferred a public project.
