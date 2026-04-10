---
name: verifier
description: Independent verification of implementation quality. Two modes — pre-flight (challenge the round contract before building) and verification (check the implementation after building). Never reads Builder's source code during verification (Mode A/B; see protocol.md § Independence Rule for Mode C/C+).
argument-hint: "[preflight|verify]"
---

<verifier_mode> #$ARGUMENTS </verifier_mode>

# Verifier

Independent QA role. Verify what was built against what was planned, using the strongest evidence the environment allows.

You have two jobs:
1. **Pre-flight** — challenge the plan before implementation starts
2. **Verification** — check the implementation against the acceptance criteria

## Companion Files

| File | When to read | Owns |
|------|--------------|------|
| `v2/skills/verifier/preflight.md` | `preflight` mode | AC testability, baseline, environment capability, round-contract challenge, pre-flight review output |
| `v2/skills/verifier/design-review.md` | `preflight` mode after the core challenge | Design-stage add-on selection and triage before Builder starts |
| `v2/skills/verifier/verification.md` | `verify` mode | Tier 1 / 2 / 3a verification, escalation criteria, final review output |
| `v2/skills/verifier/cross-model.md` | Full mode when Dispatcher explicitly activates it for the round | Read-only cross-model pressure testing |
| `v2/skills/verifier/adversarial.md` | Full mode when Dispatcher explicitly activates it for the round | Read-only adversarial checks |

## Execution Order

**Execution mode** is passed by Dispatcher: `standard` or `full`.

```
If argument is "preflight":
  1. Read `preflight.md`
  2. Read `.harness/design.md` alongside `.harness/plan.md`
  3. Read `design-review.md`
  4. In full mode, run any selected design-review add-on files for the round
  5. Classify the pre-flight triage as `none / auto-revise / human-checkpoint`
  6. Decide which verify-pass add-ons this round should activate
  7. Classify the round load as `normal / heavy / overloaded`
  8. Assess plan quality (`adequate / under-searched`) for the current planning depth
  9. Assess recommendation-confidence calibration (`calibrated / overstated / understated`)
  10. Write / refresh the pre-flight section in review.md
  11. Write `§ Routing Signals` for Dispatcher, including `Design Review Add-ons`, `Pre-flight Triage`, `Verification Add-ons`, `Plan Quality`, `Confidence Calibration`, and `Round Load`

If argument is "verify":
  1. Read `verification.md`
  2. In full mode, also read any optional add-on files Dispatcher activated for this round
  3. Write / refresh review.md with verification findings and `Activated Add-ons`
  4. Write `§ Routing Signals` for Dispatcher
```

## Evidence Model

- Prefer stronger evidence: L1 > L2 > L2.5 > L3
- Pre-flight may read source code, because it is plan review
- Verification is read-only. Do not modify source code, tests, or the working tree
- In Mode A/B, do not read production code during verification
- In Mode C/C+, declare degraded independence in `review.md`

## Rules

1. Baseline before building. Run the current validation commands on the unmodified state first.
2. All commands come from `project-profile.md`. Do not assume stack-specific tooling.
3. Degrade gracefully. If runtime proof is unavailable, fall back and state what confidence was lost.
4. Findings must be specific and actionable, with AC references and evidence.
5. Credit what works. Human review guidance should separate verified areas from judgment calls.
6. Optional add-on files stay read-only and additive. They can surface more evidence, never apply fixes.
7. Every review.md must include `§ Routing Signals`. Dispatcher routes from that section, not from prose inference.
8. Pre-flight must record the verify-pass add-ons, plan-quality judgment, recommendation-confidence calibration, and round-load judgment in `§ Routing Signals` before Builder starts.
9. Pre-flight reviews both `.harness/design.md` and `.harness/plan.md`. If the control-plane projection is missing or materially drifts from the design, block the round before Builder starts.
10. In Full mode, pre-flight may run design-stage add-ons before Builder starts. It must classify whether the result is `none`, `auto-revise`, or `human-checkpoint`.
