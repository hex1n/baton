# Verifier Module: Cross-model Review

> Requires: [codex-plugin-cc](https://github.com/openai/codex-plugin-cc) installed and configured in project-profile.md § External Reviewer.
> Activated by: Dispatch in Full mode when Mode C+ is detected.
> Evidence level: L2.5 (cross-model) — different model = different blind spots.

## Pre-flight: Cross-model Plan Challenge

After completing core Step 5 (Plan Quality Challenge), run this step.

```
1. Run /codex:adversarial-review on brief.md
   → Focus: "Challenge the acceptance criteria and approach.
     Are there hidden assumptions? Missing edge cases?
     Does the approach conflict with the codebase's actual patterns?"

2. Retrieve results via /codex:result

3. Cross-examine each Codex finding (Verifier evaluates Codex's output):
   For each finding Codex raised:
   a. Can you verify it? Read the relevant source files, check if Codex's
      claim is factually accurate against the actual codebase.
   b. Classify:
      → ✅ Confirmed: Codex is right, Verifier missed this. Add to challenges
        with file:line evidence. Tag [cross-model, confirmed].
      → ⚠️ Plausible: Codex may be right but Verifier can't verify
        (e.g., domain knowledge gap). Surface to human. Tag [cross-model, unverified].
      → ❌ Rejected: Codex is wrong (e.g., cites behavior that doesn't match code).
        Note rejection reason briefly. Do NOT include in challenges.

4. Merge confirmed/plausible findings with Verifier's own (Step 5) challenges:
   → Cross-model findings do NOT count toward the 5-challenge limit
   → Deduplicate: if Codex raises the same issue as Verifier,
     keep Verifier's version (it has file:line citations)
```

**The cross-examination is the key step.** Without it, Codex findings are just another
model's opinion. With it, each finding is either grounded in code evidence (confirmed),
flagged for human judgment (plausible), or eliminated (rejected).

### Pre-flight eval.md section (append to core eval.md output)

```markdown
### Cross-model Plan Challenge
- Source: codex-plugin-cc `/codex:adversarial-review` (L2.5)
- Codex raised: {N} findings → Verifier cross-examined → {confirmed} ✅ / {plausible} ⚠️ / {rejected} ❌
- [cross-model, confirmed] {finding with Verifier's file:line evidence}
- [cross-model, unverified] {finding Verifier couldn't verify — needs human judgment}
- {or "Not available" or "No additional findings"}
```

---

## Verification: Cross-model Code Review

After completing core Step 3 (Tier 3a AC Coverage), run this step.

```
1. Run /codex:review --base {round-start-commit}
   → Codex reviews all changes since the round started
   → This is a read-only review — Codex does not modify code

2. If this is the final round, also run:
   /codex:adversarial-review --base {round-start-commit}
   → Codex challenges design choices and assumptions
   → Pass brief.md ACs as focus context for targeted pressure-testing

3. Retrieve results:
   → /codex:status to check completion
   → /codex:result to get findings

4. Cross-examine each Codex finding (same process as pre-flight):
   For each finding:
   a. Verify against test results (Tier 1) and AC coverage (Tier 3a) —
      does the finding align with what you've already observed?
   b. Classify:
      → ✅ Confirmed: Codex found something real that Verifier's own checks missed.
        Tag [cross-model, confirmed]. Add to § Findings with evidence.
      → ⚠️ Plausible: can't verify without reading production code (which Verifier
        avoids in Mode A/B). Surface to human in § Recommend you review.
        Tag [cross-model, unverified].
      → ❌ Rejected: contradicts Tier 1 evidence (e.g., Codex says test fails but
        it actually passes). Note briefly. Do NOT include in findings.

5. If Codex is unavailable (not installed, auth error, timeout):
   → Fall back to Mode C (same-model review)
   → Note in eval.md: "Cross-model review unavailable, fell back to L3"
```

### Verification eval.md section (append to core eval.md output)

```markdown
### Cross-model Review
- Reviewer: codex-plugin-cc
- Evidence level: L2.5 (cross-model, cross-examined by Verifier)
- Codex raised: {N} findings → Verifier cross-examined → {confirmed} ✅ / {plausible} ⚠️ / {rejected} ❌
- [cross-model, confirmed] {finding with Verifier's corroborating evidence}
- [cross-model, unverified] {finding needing human review}
  {or "N/A" or "Unavailable, fell back to L3"}
```

---

## Optional: `/codex:rescue`

If Codex identifies a fixable issue, Verifier MAY use `/codex:rescue` to let Codex attempt the fix directly (runs in background). This is a cross-model alternative to routing back to Builder. Use only for small, isolated code bugs where Builder has already failed once on the same issue.

## Rules (module-specific)

1. **L2.5 findings are never accepted blindly.** Cross-examine every Codex finding against codebase evidence. Classify as confirmed/plausible/rejected.
2. **Prioritize L2.5 over L3.** When cross-model review is available, prefer it over same-model code review.
