# Slice Packet: Round {N} Slice {M}

## Metadata

| Key | Value |
|-----|-------|
| Round | {N} |
| Slice | {M} |
| Trigger | {plan slice / verifier finding / fix slice} |
| Delegation Mode | {advisory / isolated} |
| Start SHA | {git sha before delegation} |
| Packet Owner | Builder |

## Objective

{One-sentence summary of the slice this packet covers.}

## Scope Slice

- {Exact AC or Verifier finding this packet covers}
- {Second scope item if needed}

## Allowed Files

- `{path/to/file}`
- `{path/to/other-file}`

## Forbidden Actions

- Do not update `.harness/plan.md`
- Do not update `.harness/review.md`
- Do not ask the human directly
- Do not invoke `v2/tools/external-review.sh`
- Do not widen scope beyond this packet

## Acceptance Checks

- {Observable outcome that must be true when this slice is done}
- {Second observable outcome}

## Test Commands

- Compile / check: `{command from project-profile.md or N/A}`
- Tests: `{command from project-profile.md or N/A}`

## Context Snippets

- `{path/to/file}` L{N}-{M}: {why this snippet matters}
- `{path/to/other-file}` L{N}: {relevant constraint or pattern}

## Expected Outputs

- Report markdown: `.context/baton/active/slices/round-{N}/slice-{M}/report.md`
- Report JSON: `.context/baton/active/slices/round-{N}/slice-{M}/report.json`
- Patch: `.context/baton/active/slices/round-{N}/slice-{M}/patch.diff` (optional)
