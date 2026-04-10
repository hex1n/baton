# Verifier Guide: Design-Stage Review Add-ons & Triage

> Use this file during pre-flight after the core plan challenge. It governs design-stage add-on selection and triage before Builder starts.

## Goal

Stress-test `.harness/design.md` + `.harness/plan.md` before implementation begins, then decide whether Baton should:

- proceed to the human approval checkpoint
- auto-revise the design/plan through Planner before the checkpoint
- stop at a human checkpoint because the findings would change semantics, scope, or policy

## Design Review Add-ons

Design-stage add-ons are separate from verify-pass add-ons.

- `adversarial` = try to break the design before code exists
- `cross-model` = apply a different model's blind spots to the design before code exists

Record the selected set in:

```text
review.md § Pre-flight → Design Review Add-ons
review.md § Routing Signals → Design Review Add-ons
```

## Default Selection Rules

Recommend `adversarial` for the pre-flight design review if any of:

- `Planning Depth = deepen`
- `Scope Class = S4`
- `Risk Class = R3`
- `Verifier Mode = C/C+`
- the round touches:
  - transaction boundaries
  - concurrency / locking
  - idempotency chains
  - delete-and-rebuild / replace semantics
  - shared-state mutation
  - irreversible side effects
  - protocol / validator / control-plane behavior

Recommend `cross-model` for the pre-flight design review only if an external reviewer is available and at least one of:

- the human explicitly asked for it
- `adversarial` is already selected
- the round changes protocol / validators / control-plane behavior
- confidence remains degraded after the core challenge
- the round is both high-risk and design-heavy

Otherwise use `none`.

## Triage Rules

After the core challenge and any selected design-review add-ons, classify the pre-flight findings into one of three actions:

### `none`

Use when:

- no design-stage finding requires replanning beyond the normal approval checkpoint
- or findings are already captured as non-blocking human review notes

### `auto-revise`

Use only when every design-stage finding is structurally fixable inside the current task direction and does **not** require a human semantic choice.

Typical `auto-revise` findings:

- weak or solution-shaped problem framing
- missing or shallow alternatives on a deepen round
- missing `Need Confirmation` projection into `plan.md § Open Decisions`
- projection drift between `design.md` and `plan.md`
- overstated confidence or weak confidence basis
- missing risk / rollback / compatibility / self-check sections
- slices too coarse or verification plan too weak
- design-review add-on findings that sharpen the existing plan without changing product semantics

`auto-revise` is a single bounded attempt per round. If Dispatcher re-runs Planner once for structural repair and the next pre-flight still finds auto-revise-class issues, escalate to `human-checkpoint` instead of looping.

### `human-checkpoint`

Use when any finding would change semantics, scope, or policy, or needs a real human answer.

Typical `human-checkpoint` findings:

- business semantics or invariants need to change
- API / contract direction changes
- rollout or rollback policy changes materially
- scope needs to expand, shrink, or split around product intent
- the design exposes a new open decision that the human must answer
- cross-model or adversarial findings remain plausible but cannot be verified enough for auto-revision

## Routing Contract

When triage is:

- `none`
  - `Next Route = human`
  - `Human Review Needed = yes`
  - `Blocking = none` unless another blocker already exists

- `auto-revise`
  - `Next Route = planner`
  - `Human Review Needed = no`
  - `Blocking = design-issue`
  - Dispatcher should route Planner automatically before the approval checkpoint

- `human-checkpoint`
  - `Next Route = human`
  - `Human Review Needed = yes`
  - `Blocking = design-issue` or `requirement-gap`, whichever best fits the finding

## Output Contract

Append to `review.md § Pre-flight`:

```markdown
### Design Review Add-ons
- Used: `{none / adversarial / cross-model / adversarial,cross-model}`
- Why: `{brief reason}`

### Pre-flight Triage
- Action: `{none / auto-revise / human-checkpoint}`
- Why: `{brief reason}`
```
