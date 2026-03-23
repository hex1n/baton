---
name: verify
description: Run the test suite to verify changes. Use after modifying hook scripts, setup.sh, or the CLI. Accepts optional argument for scope.
---

# Verify

Run the baton test suite to verify your changes are correct.

## Usage

- `/verify` or `/verify smoke` — run the quick smoke test (default, recommended after most changes)
- `/verify full` — run the full regression suite (use before commits or after cross-cutting changes)
- `/verify <test-name>` — run a specific test file (e.g., `/verify write-lock` runs `tests/test-write-lock.sh`)

## Steps

1. Determine which test to run based on `$ARGUMENTS`:
   - Empty or `smoke` → `bash tests/test-smoke.sh`
   - `full` → `bash tests/test-full.sh`
   - Any other value → `bash tests/test-$ARGUMENTS.sh` (verify the file exists first)

2. Run the test using the Bash tool with `timeout: 300000` (tests can be slow on Windows/Git Bash).

3. Report results:
   - If all assertions pass: state the pass count and which suite ran.
   - If any fail: list each failing assertion with its context, then suggest which files to investigate.
