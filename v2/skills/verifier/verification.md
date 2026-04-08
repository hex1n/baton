# Verifier Guide: Verification

> Invoked after Builder completes. Goal: independently verify the implementation against `plan.md`.

**Critical boundary:** Do not read Builder's production source code during verification in Mode A/B. Verification is read-only in all modes.

## Step 1: Tier 1 — Deterministic Verification

```text
Run: project test command (from project-profile.md)

Compare to baseline:
  Before: {pass} pass / {fail} fail
  After:  {pass} pass / {fail} fail

  New tests added: {count} ✅
  New failures: {count} ❌
    {TestId} — was passing, now failing
    → This is a regression introduced by Builder

  Baseline failures still failing: {count} (unchanged)
```

If any new failures appear, fail immediately. Code bugs are cheapest to fix here.

## Step 2: Tier 2 — Runtime Verification (Mode A/B)

Skip in Mode C/C+. Note the skip clearly in `review.md`.

If Mode A:

```text
a) Start the application (run command from project-profile.md)
b) Perform the readiness check
c) For each AC:
   → execute the scenario
   → check response / output
   → verify state change if applicable
d) Run project-profile.md § Verification Checks
e) Stop the application
```

If Mode B:

```text
a) Skip app startup and readiness check
b) Attempt partial verification for each AC using whatever services are available
c) Run only the verification checks that do not require the full app
d) Record what ran and what was skipped
```

Tier 2 checks are project-specific. Use `project-profile.md § Verification Checks`, not hardcoded assumptions.

## Step 3: Tier 3a — AC Coverage Verification

For each AC in `plan.md`:

```text
AC-{N}.1: "Given {precondition}, When {action}, Then {expected outcome}"
  Builder's test: {test identifier}
  Test exists? ✅
  Test passes? ✅
  Test actually verifies the AC? ✅ / ⚠️
```

Check test quality, not just existence:
- read only the test files, not production code
- confirm assertions match the AC
- flag trivial tests that pass without proving the required outcome

Assertion-density pressure test:

```text
{test identifier}:
  Lines of test code: {N}
  Assertion count: {N}
  Density: {assertions / lines}
  Verdict: ✅ adequate / ⚠️ low density
```

Low assertion density often means the test exercises code paths without truly verifying behavior.

## Step 4: Critical-path Rerun (Optional, Read-only)

For 1-2 high-risk ACs:

```text
1. Identify the highest-risk ACs from Tier 1 + Tier 3a
2. Re-run only the mapped tests or validation commands already associated with those ACs
3. Confirm the assertions still hold in isolation
4. If isolated evidence is weaker than the full suite implies,
   flag the test as weak and route it back to Builder
```

## Step 5: Output `review.md`

```markdown
# Review: Round {N}

## Pre-flight
{included for reference}

## Verification

### Tier 1: Deterministic
- Compile/check: ✅
- Tests: {pass} pass / {fail} fail
  - New tests: {count} ✅
  - Regressions: {count} ✅/❌
  - Baseline failures: {count} (unchanged)

### Tier 2: Runtime
- App startup: ✅ ({time}) / skipped (Mode B/C)
- Health check: ✅ / skipped
- AC scenarios: {executed} / {skipped}
- Verification checks: {pass} / {skip} / {fail}

### Tier 3a: AC Coverage
| AC | Test | Exists | Passes | Verifies AC |
|----|------|--------|--------|-------------|
| AC-{N}.1 | {test identifier} | ✅ | ✅ | ✅ |
| AC-{N}.2 | {test identifier} | ✅ | ✅ | ⚠️ weak assertion |

## Findings

### Code bugs
1. {specific, actionable finding with AC reference}

### Design issues
{None or specific findings.}

### Requirement gaps
{None or specific gaps.}

### Findings Sidecar
- Path: {.context/baton/active/findings/review-round-{N}.json or N/A}
- Status: {written / not needed}
- Summary: {normalized findings for tooling, or "N/A"}

## Human Judgment

### Already verified
- ✅ {what Verifier confirmed with high confidence}

### Needs your judgment
1. **{item}** — {why human judgment is still needed}

### Risk note
Verifier ran in Mode {A/B/C}. Confidence: {high/medium/low}.

### Independence note
⚠️ Verification independence: degraded — human review weight is higher.

## Routing Signals
| Key | Value |
|-----|-------|
| Next Route | {builder / planner / human / closeout} |
| Human Review Needed | {yes / no} |
| Blocking | {none / code-bug / design-issue / requirement-gap / environment} |
```

If you produced non-trivial findings, also write a normalized JSON sidecar at:

```text
.context/baton/active/findings/review-round-{N}.json
```

Use `v2/templates/review-findings.template.json` as the shape. `review.md` remains the canonical
human-facing artifact; the JSON sidecar is scratch state for tooling and later aggregation.

## Escalation Criteria

Classify findings as:

```text
Code bug (→ Builder):
  - fixable in ≤ 3 files
  - does not require changing plan.md decisions
  - examples: wrong status code, missing validation, weak assertion

Design issue (→ Planner):
  - requires changing the planned approach
  - or the same code bug persists after repeated Builder attempts
  - examples: wrong integration pattern, transaction boundary issue, module coupling

Requirement gap (→ Human):
  - AC is ambiguous or contradictory
  - real-world scenario is uncovered
  - business judgment is required
```

Reclassification heuristic:
- if a supposed "code bug" fix grows beyond 3 files or changes the approach, reclassify it as a design issue
- if the same finding reappears in consecutive evals with different wording, treat it as the same issue for escalation counting

Routing signal defaults:
- PASS → `Next Route = human`, `Human Review Needed = yes`, `Blocking = none`
- Code bugs only → `Next Route = builder`, `Human Review Needed = no`, `Blocking = code-bug`
- Design issues → `Next Route = planner`, `Human Review Needed = no`, `Blocking = design-issue`
- Requirement gaps → `Next Route = human`, `Human Review Needed = yes`, `Blocking = requirement-gap`
- Verification blocked by environment or missing evidence → `Next Route = human`, `Human Review Needed = yes`, `Blocking = environment`
- If Dispatcher can terminate immediately without another human checkpoint, use `Next Route = closeout`
