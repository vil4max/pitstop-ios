# App-owned. Runtime recipes come from Tooling/.
# harness-update does not overwrite this file after the first install.
import 'Tooling/justfile'

# App-local recipes below (human + agent).

# Keep CI on the same verification path; fail on uncommitted formatter changes.
verify-ci:
    swiftformat . --lint --config Tooling/.swiftformat
    just doctor --json
    just verify
    git diff --exit-code
