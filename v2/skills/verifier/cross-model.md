# Verifier Guide: Cross-model Review

> Requires: `project-profile.md § External Reviewer` configured and `bash v2/tools/external-review.sh` available.
> Activated by: Verifier during Full-mode pre-flight or verification when selected for the round and the external reviewer is available.
> Evidence level: L2.5 (cross-model) — different model = different blind spots.

Raw adapter/provider outputs live under:

```text
.context/baton/active/external-review/{job_id}/
```

Normalized findings should be merged into:

```text
.context/baton/active/findings/review-round-{N}.json
```

## Pre-flight: Cross-model Design Challenge

After completing the core pre-flight challenge, run this step.

The external reviewer receives `.harness/design.md` as the primary planning artifact. Verifier must still cross-examine the result against both `.harness/design.md` and `.harness/plan.md`, because Baton routing depends on the projection remaining faithful.

```text
1. Start a challenge job:
   bash v2/tools/external-review.sh start \
     --repo-root . \
     --kind challenge \
     --input .harness/design.md \
     --focus "Challenge the proposed design. What hidden assumptions, missing edge cases, rollback gaps, or semantic risks could make this approach fail in the real codebase?"
   → Capture the returned Baton job id

2. Check progress and fetch the output:
   bash v2/tools/external-review.sh status --repo-root . --job-id {job_id}
   bash v2/tools/external-review.sh result --repo-root . --job-id {job_id}

3. Cross-examine each external finding:
   For each finding the external reviewer raised:
   a. Read the relevant source files and check whether the claim is factually
      accurate against the actual codebase and the projected `plan.md`.
   b. Classify:
      → ✅ Confirmed, auto-revise: the reviewer is right and the fix stays within the
        approved task direction. Tag [cross-model, auto-revise].
      → ⚠️ Confirmed, needs-human: the reviewer is right but fixing it would change
        semantics, scope, or policy. Tag [cross-model, needs-human].
      → ⚠️ Plausible: the reviewer may be right but Verifier cannot verify enough for
        automatic revision. Surface to human. Tag [cross-model, needs-human].
      → ❌ Rejected: the reviewer is wrong. Note rejection reason briefly. Do NOT
        include it in canonical findings.

4. Merge the confirmed/plausible findings with Verifier's own pre-flight challenges:
   → Cross-model findings do NOT count toward the 5-challenge limit
   → Deduplicate: if the external reviewer raises the same issue as Verifier,
     keep Verifier's version with file:line evidence
```

**The cross-examination is the key step.** Without it, external-review findings are just another
model's opinion. With it, each finding is either grounded enough for auto-revision, escalated to
human judgment, or eliminated.

### Pre-flight note for review.md

If this add-on ran, summarize only the confirmed findings and the resulting triage impact in `review.md § Findings` and `§ Routing Signals`. Do not create a separate canonical section outside the core template.

---

## Verification: Cross-model Code Review

After completing core Step 3 (Tier 3a AC Coverage), run this step.

```text
1. Start a review job:
   bash v2/tools/external-review.sh start \
     --repo-root . \
     --kind review \
     --input .harness/review.md \
     --base {round-start-commit} \
     --focus "Review all changes since the round started. This is read-only review."
   → Capture the returned Baton job id

2. If this is the final round, optionally run a second challenge job:
   bash v2/tools/external-review.sh start \
     --repo-root . \
     --kind challenge \
     --input .harness/plan.md \
     --base {round-start-commit} \
     --focus "Challenge design choices and assumptions against the accepted ACs."

3. Retrieve results:
   bash v2/tools/external-review.sh status --repo-root . --job-id {job_id}
   bash v2/tools/external-review.sh result --repo-root . --job-id {job_id}

4. Cross-examine each external finding:
   For each finding:
   a. Verify against test results (Tier 1) and AC coverage (Tier 3a).
   b. Classify:
      → ✅ Confirmed: the external reviewer found something real that Verifier's own checks missed.
        Tag [cross-model, confirmed]. Add to § Findings with evidence.
      → ⚠️ Plausible: can't verify without reading production code (which Verifier
        avoids in Mode A/B). Surface to human in § Needs your judgment.
        Tag [cross-model, unverified].
      → ❌ Rejected: contradicts Tier 1 evidence. Note briefly. Do NOT include in findings.

5. If the adapter or provider is unavailable:
   → Fall back to Mode C (same-model review)
   → Note in review.md: "Cross-model review unavailable, fell back to L3"
```

### Verification review.md section (append to core review.md output)

```markdown
### Cross-model Review
- Reviewer: external-review adapter (provider: {provider})
- Evidence level: L2.5 (cross-model, cross-examined by Verifier)
- Reviewer raised: {N} findings → Verifier cross-examined → {confirmed} ✅ / {plausible} ⚠️ / {rejected} ❌
- [cross-model, confirmed] {finding with Verifier's corroborating evidence}
- [cross-model, unverified] {finding needing human review}
  {or "N/A" or "Unavailable, fell back to L3"}
```

## Rules (file-specific)

1. **L2.5 findings are never accepted blindly.** Cross-examine every external-review finding against codebase evidence. In pre-flight, classify as auto-revise / needs-human / rejected. In verification, classify as confirmed / unverified / rejected.
2. **Prioritize L2.5 over L3.** When cross-model review is available, prefer it over same-model review.
3. **Cross-model review stays read-only.** This file may surface findings, never trigger or apply fixes directly. All code changes still route through Planner or Builder.
4. **Scratch stays non-canonical.** If a finding matters for routing or human judgment, summarize it in `review.md`. Do not leave it only in `.context/baton/active/`.
