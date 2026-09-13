<!-- agent-engineering-kit:commit-policy:start -->
<!-- Generated from agent-engineering-kit/rules/conventional-commits.mdc; do not edit this block by hand. -->
# Commit messages

- Write commit messages in English only, without emojis.
- Use `<type>: <summary>` or `<type>(<scope>): <summary>`.
- Allowed types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `build`, `ci`, `perf`.
- Start the summary with a lowercase letter, use imperative mood, and omit the final period.
- Commit message describes the resulting repository change, not the actions performed by the coding agent.
- Do not mention Copilot, AI, generated code, agent activity, or the implementation process in the message. Describe the concrete repository behavior or configuration instead.
- Do not add `Co-authored-by` trailers; commits remain owner-only.
- Reject vague summaries such as `update code`, `make changes`, `fix issue`, `improvements`, `cleanup`, or similarly unspecific wording.
- Inspect the actual staged diff before choosing the type and optional scope. Use `feat` only for new user-visible functionality, `fix` only for corrected incorrect behavior, and `refactor` when observable behavior stays unchanged.
- Use `test` for tests, `docs` for documentation, `chore` for maintenance, `build` for build systems or dependencies, `ci` for CI configuration, and `perf` for performance improvements.
- Keep one logical change per commit. When the staged diff contains unrelated changes, recommend splitting commits instead of inventing a vague umbrella summary.
- Add a body only when it contributes useful context beyond the summary: why the change is needed, behavioral consequences, or architectural decisions. Separate it with a blank line; do not repeat the summary.
- Describe breaking changes in a useful `BREAKING CHANGE:` footer when needed; keep the subject in the format above.
- Preserve Git-generated merge, revert, and autosquash messages so normal history operations keep working. These are exceptions to the authored-subject format, not additional commit types.
- Never bypass validation with `--no-verify` or the Desktop bypass control.

Examples:

```text
feat(cache): restore region status on cold launch
fix(carplay): preserve status colors during refresh
refactor(networking): isolate retry policy from request execution
docs: clarify release checklist
```
<!-- agent-engineering-kit:commit-policy:end -->
