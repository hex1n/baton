# Worker Report: Round {N} Batch {M}

## Metadata

| Key | Value |
|-----|-------|
| Round | {N} |
| Batch | {M} |
| Status | {complete / complete_with_concerns / needs_context / blocked} |
| Delegation Mode | {advisory / isolated} |

## Summary

{What the worker attempted and what happened.}

## Files Touched

- `{path/to/file}` — {created / modified / suggested}
- `{path/to/other-file}` — {created / modified / suggested}

## Commands Run

- `{command}` → {pass / fail / not run}
- `{command}` → {pass / fail / not run}

## Concerns

- {Specific concern, or `None.`}

## Open Questions

- {Missing context, ambiguity, or blocker, or `None.`}

## Patch

- Path: `{.context/baton/active/batches/round-{N}/batch-{M}/patch.diff or N/A}`
- Notes: {what Builder should review before integrating}
