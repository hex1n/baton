# Baton Scratch State

This directory holds non-canonical Baton runtime state for the current task.

Canonical control-plane artifacts stay in:

- `project-profile.md`
- `.harness/plan.md`
- `.harness/review.md`

Scratch state lives under `.context/baton/active/` and is intentionally ignored by git.

Suggested layout:

```text
.context/baton/
  ├── README.md
  └── active/
      ├── external-review/   # raw provider outputs and adapter job state
      ├── findings/          # normalized JSON sidecars for review findings
      └── exploration/       # optional scratch notes / checkpoints
```

Rules:

- Dispatcher routes from canonical artifacts, never from scratch files.
- Verifier may write scratch sidecars, but the human-facing summary stays in `.harness/review.md`.
- `archive-task.sh` may copy `active/` into the task archive as non-canonical scratch history during closeout.
