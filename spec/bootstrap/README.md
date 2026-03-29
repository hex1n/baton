# Bootstrap Layout

`spec/bootstrap/` now uses a layered layout:

- Top-level `*.sh` files are stable public entrypoints and compatibility wrappers.
- [`prepare-review.sh`](/Users/hex1n/IdeaProjects/baton/spec/bootstrap/prepare-review.sh) is the review-gate preparation entrypoint: it refreshes local hooks, runs consistency checks, smoke-tests a generated SessionStart hook command, and prints the isolated verifier / evaluator next steps.
- [`commands/`](/Users/hex1n/IdeaProjects/baton/spec/bootstrap/commands) contains the real shell implementations.
- [`lib/`](/Users/hex1n/IdeaProjects/baton/spec/bootstrap/lib) contains shared shell helpers and parsing logic.
- [`hooks/`](/Users/hex1n/IdeaProjects/baton/spec/bootstrap/hooks) contains runtime hook handlers; hook entrypoints are extensionless, and Windows uses [`run-hook.cmd`](/Users/hex1n/IdeaProjects/baton/spec/bootstrap/hooks/run-hook.cmd) as a thin launcher into Git Bash.

Cross-platform policy is intentionally simple:

- Bash is the single bootstrap/runtime implementation language.
- Windows support uses Git Bash, or `bash ...` from PowerShell.
- `spec/bootstrap/` does not keep a parallel `.ps1` business-logic layer.

For normal use, keep calling the top-level wrappers such as
`spec/bootstrap/install-harness.sh` or `spec/bootstrap/start-task.sh`. Internal
scripts should source shared helpers from `lib/` instead of duplicating logic.
