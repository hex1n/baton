# Contributing to Baton

Baton core is not "just documentation." The protocol, role files, templates, and validators shape agent behavior. Treat changes there like code changes.

## Repository Layers

| Layer | Location | Purpose | Inclusion bar |
|-------|----------|---------|---------------|
| Core | `v2/` | General-purpose Baton protocol, public role entrypoints, templates, validators | Must support Baton's three core assumptions across projects |
| Companion | `skills/` | Optional supporting skills outside the core Baton loop | Useful add-ons, but Baton core must not depend on them |
| External adapters / plugins | `v2/tools/` wrappers or separate repos/plugins | Host-specific or provider-specific integrations | Keep runtime/vendor details out of protocol and public role entrypoints |

If a change is project-specific, domain-specific, team-specific, or primarily about one external tool, it does not belong in core.

## Behavior-Shaping Files

Changes to any of the files below are behavior-shaping changes:

- `v2/protocol.md`
- `v2/skills/**`
- `v2/templates/**`
- `v2/tools/check-*.sh`
- `v2/tools/validate-*.sh`
- `README.md`
- `README.zh-CN.md`
- `CLAUDE.md`
- `v2/CLAUDE.md`

These files define how Baton routes work, what each role may do, and how live state is interpreted.

## Change Policy

For behavior-shaping changes:

1. Update `v2/protocol.md` first if the rule itself changed.
2. Sync every affected projection layer in the same change.
3. Add an eval note to the commit, PR, or task record describing:
   - the concrete problem being solved
   - which behavior changed
   - which validators / contract tests were run
   - any remaining risk or manual follow-up
4. Keep the change scoped to one problem whenever possible.
5. If the change touches Builder delegation, preserve the public-role boundary: Builder remains the only canonical mutator and `.harness/*` remains canonical.

## What Does Not Belong in Core

- Host-specific command syntax in the protocol or public role entrypoints
- Vendor installation instructions in core protocol rules
- Domain workflows that Baton core does not require
- Companion skills becoming mandatory parts of the Dispatcher → Planner → Builder → Verifier loop
- Internal Builder workers exposed as a fifth public role
- "Cleanup" rewrites of role instructions without a concrete behavior reason

## Builder Delegation Boundary

Builder may gain internal helper workflows over time, but the boundary is fixed:

- Internal workers are part of Builder, not public Baton roles
- Internal workers may not write `.harness/plan.md` or `.harness/review.md`
- Internal workers may not ask humans directly or invoke external review
- Scratch artifacts under `.context/baton/` may support Builder, but canonical routing still comes only from `plan.md` and `review.md`

## Validation Checklist

Before merging a core change, run:

```bash
bash v2/tools/check-consistency.sh
bash v2/tools/validate-live-state.sh
bash v2/tools/validate-round-contract.sh
bash v2/tools/validate-round-sync.sh
```

`check-consistency.sh` is the repo-level entrypoint. It also runs Baton's contract tests and the live round-contract lint.
