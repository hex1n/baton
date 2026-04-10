# Verifier Guide: Adversarial Testing

> Activated by: Verifier during Full-mode pre-flight or verification when selected for the round.
> When to run: pre-flight for design-heavy high-risk rounds; verification for final rounds or any round with security-surface ACs and Mode A.

## Pre-flight: Adversarial Design Challenge

Run after the core pre-flight challenge and before Builder starts.

**Goal:** try to break `.harness/design.md` + `.harness/plan.md` before code exists by constructing realistic failure scenarios the happy path ignores.

Stress these axes:

```text
a) Semantic breakpoints:
   - Does the proposed design violate any declared invariant?
   - Does a "successful" implementation under this design still produce the wrong business outcome?

b) Concurrency / transaction breakpoints:
   - What happens if the same action runs twice?
   - Where do partial writes, retries, or lost updates appear?
   - Can replace / rebuild / delete semantics leave the system in a mixed state?

c) Compatibility / rollout breakpoints:
   - Which callers or operators would be surprised by this change?
   - Is rollback materially under-specified?
   - Does the plan assume a migration order or deployment order that is not written down?

d) Verification breakpoints:
   - Could Builder "pass" the current verification plan while the design is still wrong?
   - Are slices too coarse to isolate the risky step?
```

Classify each design-stage adversarial finding:

- `[adversarial, auto-revise]` — structurally fixable without changing product semantics, scope, or policy
- `[adversarial, needs-human]` — fixing it would change semantics, scope, rollout policy, or requires a real human choice
- rejected — plausible at first glance but not supported after Verifier cross-check

Typical `auto-revise` findings:

- failure mode missing from `Self-Check`
- weak rollback / compatibility notes
- verification plan can be tightened without changing the direction
- slices obscure the risky step but can be re-split mechanically

Typical `needs-human` findings:

- the recommended approach produces the wrong business semantics under retry / concurrency
- rollback policy is unacceptable rather than merely underwritten
- the design reveals a new required human decision

### Pre-flight note for review.md

If this add-on ran, summarize only the confirmed findings and the resulting triage impact in `review.md § Findings` and `§ Routing Signals`. Do not create a separate canonical section outside the core template.

---

## Verification: Adversarial Testing

Run after core Tier 3a (AC Coverage Verification).

**When to run:**
- **Final round:** always run full suite (a + b + c + d)
- **Any round where ACs touch auth, input parsing, or data mutation AND Mode A available:**
  run (a) input boundaries + (b) auth attacks only
- Verifier determines applicability from AC content, not a manual tag

```text
a) Input boundary attacks:
   - Empty / missing required input → should get validation error, not crash
   - Negative or zero values where positive expected → should reject
   - Maximum boundary values (e.g., MAX_INT) → should handle gracefully
   - Injection payloads (SQL, command, XSS as applicable) → should be sanitized
   - Extremely large input → should not cause OOM or timeout

b) Authorization attacks (if applicable):
   - Call without auth → should be rejected
   - Call with wrong user's credentials → should be forbidden
   - Privilege escalation → should be blocked

c) Concurrency attacks:
   - Same operation from multiple threads simultaneously
   - Check: no duplicate records, no data corruption, no lost updates

d) Resource exhaustion:
   - High-frequency repeated operations → should not degrade performance
   - Check: connection pool stable, no resource leaks
```

**Adversarial findings are categorized as P1/P2/P3:**
- P1 (blocks shipping): SQL injection possible, data corruption, auth bypass
- P2 (should fix): missing input validation, no rate limiting
- P3 (nice to have): verbose error messages, slow response under extreme load

### Verification review.md section (append to core review.md output)

```markdown
### Adversarial Testing
- P1: {critical security / data integrity issues}
- P2: {should-fix issues}
- P3: {nice-to-have improvements}
```
