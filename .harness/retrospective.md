# Retrospective: add-version-flag

## 1. Outcome

- Closed as: complete
- Main blocker: `script_dir` unbound variable (caught by Evaluator, fixed in 1 repair round)
- Human decision: architecture approved (VERSION file approach)

## 2. What Worked

- Full 6-role loop executed. Protocol is viable.
- Evaluator caught a real bug that Generator missed — independent context works.
- Repair loop completed in 1 round, no escalation.
- VERSION file approach: single source, zero complexity, language-agnostic.

## 3. What Failed

- Generator placed `--version` case in arg loop that runs before `script_dir` assignment. Pattern-followed `--help` (which doesn't need paths) without checking the new case's dependencies.
- Skill auto-discovery: `Skill` tool couldn't find `harness-explorer`. May need registration or naming adjustment.

## 4. Repo-Specific Lessons

- Bootstrap scripts should resolve `script_dir` early (top of file) — any future flag may need paths.
- No test infra for bootstrap scripts. Consider minimal smoke tests for non-trivial future changes.
- `.harness/` artifacts uncommitted — decide: commit as task history, or gitignore as transient?

## 5. Harness Lessons

- **Trivial tasks produce sparse artifacts.** Most artifact sections were near-empty. Protocol could benefit from a "trivial mode" — inline plan instead of 6 separate files.
- **Human gate overhead was appropriate.** Architecture approval was a single "ok" — the protocol doesn't over-prescribe approval depth for small tasks.
- **Evaluator value proven.** The bug was exactly the kind that self-review misses: correct logic, wrong placement, only visible at runtime.

## 6. Standardization Candidates

- Move `script_dir` resolution to top of all bootstrap scripts (done in this task).
- Add `--version` to bootstrap script template or docs so new scripts include it by default.
