# Verifier Guide: Cross-model Review

> Requires: `project-profile.md § External Reviewer` configured and `bash v2/tools/external-review.sh` available.
> Activated by: Dispatcher during Full-mode review when selected for the round and the external reviewer is available.
> Evidence level: L2.5 (cross-model) — different model = different blind spots.

Raw adapter/provider outputs live under:

```text
.context/baton/active/external-review/{job_id}/
```

Normalized findings should be merged into:

```text
.context/baton/active/findings/review-round-{N}.json
```

## Pre-flight: Cross-model Plan Challenge

After completing core Step 5 (Plan Quality Challenge), run this step.

```
1. Start a challenge job:
   bash v2/tools/external-review.sh start \
     --repo-root . \
     --kind challenge \
     --input .harness/plan.md \
     --focus "Challenge the acceptance criteria and approach. Are there hidden assumptions? Missing edge cases? Does the approach conflict with the codebase's actual patterns?"
   → Capture the returned Baton job id

2. Check progress and fetch the output:
   bash v2/tools/external-review.sh status --repo-root . --job-id {job_id}
   bash v2/tools/external-review.sh result --repo-root . --job-id {job_id}

3. Cross-examine each external finding:
   For each finding the external reviewer raised:
   a. Can you verify it? Read the relevant source files and check whether the
      claim is factually accurate against the actual codebase.
   b. Classify:
      → ✅ Confirmed: the external reviewer is right, Verifier missed this. Add to challenges
        with file:line evidence. Tag [cross-model, confirmed].
      → ⚠️ Plausible: the external reviewer may be right but Verifier can't verify
        (e.g., domain knowledge gap). Surface to human. Tag [cross-model, unverified].
      → ❌ Rejected: the external reviewer is wrong (e.g., cites behavior that doesn't match code).
        Note rejection reason briefly. Do NOT include in challenges.

4. Merge confirmed/plausible findings with Verifier's own (Step 5) challenges:
   → Cross-model findings do NOT count toward the 5-challenge limit
   → Deduplicate: if the external reviewer raises the same issue as Verifier,
     keep Verifier's version (it has file:line citations)
```

**The cross-examination is the key step.** Without it, external-review findings are just another
model's opinion. With it, each finding is either grounded in code evidence (confirmed),
flagged for human judgment (plausible), or eliminated (rejected).

### Pre-flight review.md section (append to core review.md output)

```markdown
### Cross-model Plan Challenge
- Source: external-review adapter (provider: {provider}, job: {job_id}) (L2.5)
- Reviewer raised: {N} findings → Verifier cross-examined → {confirmed} ✅ / {plausible} ⚠️ / {rejected} ❌
- [cross-model, confirmed] {finding with Verifier's file:line evidence}
- [cross-model, unverified] {finding Verifier couldn't verify — needs human judgment}
- {or "Not available" or "No additional findings"}
```

---

## Verification: Cross-model Code Review

After completing core Step 3 (Tier 3a AC Coverage), run this step.

```
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

4. Cross-examine each external finding (same process as pre-flight):
   For each finding:
   a. Verify against test results (Tier 1) and AC coverage (Tier 3a) —
      does the finding align with what you've already observed?
   b. Classify:
      → ✅ Confirmed: the external reviewer found something real that Verifier's own checks missed.
        Tag [cross-model, confirmed]. Add to § Findings with evidence.
      → ⚠️ Plausible: can't verify without reading production code (which Verifier
        avoids in Mode A/B). Surface to human in § Needs your judgment.
        Tag [cross-model, unverified].
      → ❌ Rejected: contradicts Tier 1 evidence (e.g., reviewer says test fails but
        it actually passes). Note briefly. Do NOT include in findings.

5. If the adapter or provider is unavailable (not installed, auth error, timeout):
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

1. **L2.5 findings are never accepted blindly.** Cross-examine every external-review finding against codebase evidence. Classify as confirmed/plausible/rejected.
2. **Prioritize L2.5 over L3.** When cross-model review is available, prefer it over same-model code review.
3. **Cross-model review stays read-only.** This file may surface findings, never trigger or apply fixes. All code changes still route through Builder.
4. **Scratch stays non-canonical.** If a finding matters for routing or human judgment, summarize it in `review.md`. Do not leave it only in `.context/baton/active/`.
