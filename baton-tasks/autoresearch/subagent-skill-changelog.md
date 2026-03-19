# baton-subagent SKILL.md — Autoresearch Changelog

Date: 2026-03-20
Method: autoresearch (scenario simulation + iterative scoring)

---

## Scoring Criteria

| # | Criterion |
|---|-----------|
| Q1 | write-write **and** write-read conflict checks on **all** candidate items |
| Q2 | each subagent receives **only necessary context** (not full plan / full Todo list) |
| Q3 | completion check verifies **spec compliance + write set boundary** (not just status) |
| Q4 | **cross-item integration tests** run after absorption |

---

## Round 1 — Baseline (skill unchanged)

### Scenario A: 3 independent hook scripts, each in its own file
All items: no shared files, no dependencies.

| Q1 | Q2 | Q3 | Q4 |
|----|----|----|-----|
| ✅ | ✅ | ✅ | ✅ |

**4/4**

### Scenario B: 2 items where Item 2's read set depends on Item 1's write set
(write-read conflict: Item 1 writes `auth.ts`, Item 2 reads `auth.ts`)

| Q1 | Q2 | Q3 | Q4 |
|----|----|----|-----|
| ❌ | ✅ | ✅ | ✅ |

**3/4** — Q1 fails.

Root cause: Step 1 says "partition into parallel batches and sequential chains" using write-write analysis only, then appends "Write-read conflicts checked after Step 2" as a trailing note. No signal that the Step 1 grouping is provisional. An agent commits to "parallel" in Step 1 and can treat it as final, missing the write-read revision step.

### Scenario C: 4 items, Items 1 & 2 share an exports file (write-write conflict)
Items 1+2: write-write conflict on `index.ts` → sequential. Items 3+4: no conflict → parallel.

| Q1 | Q2 | Q3 | Q4 |
|----|----|----|-----|
| ✅ | ✅ | ✅ | ✅ |

**4/4**

### Round 1 Total: 11/12

---

## Round 2 — Fix Q1 gap + surface Q2 gap for sequential chains

**Q1 fix (Changes A + B):**
- Step 1 item 3: marked grouping as "(provisional)" and noted it is finalized after Step 2's write-read check.
- Step 2 write-read block: added "(revises Step 1 grouping)" to the header and explicit instruction to revise the provisional grouping before proceeding to Step 3.

**Q2 gap surfaced:**
After enforcing sequential execution for Scenario B, a new failure mode appeared: Step 2 frames context construction without timing guidance, so an agent could build all contexts upfront before any dispatch. In a write-read sequential chain, Item 2 would then receive the *pre-Item-1* version of `auth.ts` — stale, wrong content.

**Q2 fix (Change C):**
Added to Step 3: "For sequential items: construct context immediately before dispatch — re-read write set and read set files from disk after preceding items complete. Do not build all sequential contexts upfront."

**Re-score after Round 2 (projected):**

| Scenario | Q1 | Q2 | Q3 | Q4 | Total |
|----------|----|----|----|----|-------|
| A | ✅ | ✅ | ✅ | ✅ | 4/4 |
| B | ✅ | ✅ | ✅ | ✅ | 4/4 |
| C | ✅ | ✅ | ✅ | ✅ | 4/4 |

**Round 2 Total: 12/12**

---

## Round 3 — Quality refinements (no score reversals)

**Q3 quality improvement (Change D):**
"spec compliance (Summary matches Todo intent)" was too narrow — it bound spec compliance to checking the narrative Summary field, not the actual changed content. An agent could produce a plausible Summary for wrong changes. Reworded to: "actual changes match Todo intent — use Summary as entry point, verify directly against write set content if Summary is ambiguous or partial."

**Q2 scope tightening (Change E):**
"Plan summary" was undefined, leaving room to include other items' status or unrelated context. Added inline clarification: "objective, constraints, and architectural decisions relevant to this item only — not other items' status or unrelated context."

---

## Round 4 — Final review (no changes)

All 5 changes reviewed for contradictions, over-specification, and cross-scenario coverage. None introduced regressions. Changes locked.

---

## Final Score: 12/12

---

## Changes Applied to SKILL.md

### Change A — Step 1 item 3: provisional grouping
```diff
- 3. **Group** — partition into parallel batches and sequential chains. Write-read conflicts checked after Step 2.
+ 3. **Group (provisional)** — partition into parallel batches and sequential chains based on write-write analysis only. This partition is provisional; it may be revised after the write-read conflict check in Step 2.
```
**Fixes**: Q1 failure in Scenario B.

### Change B — Step 2 write-read block: explicit revision instruction
```diff
- **Write-read conflict check** — after constructing read sets, verify no item's write set overlaps another's read set. Conflicts force sequential execution (writer before reader).
+ **Write-read conflict check (revises Step 1 grouping)** — after constructing read sets for ALL items in the batch, verify no item's write set overlaps another's read set. Any conflict forces sequential execution (writer before reader); revise the provisional Step 1 grouping accordingly before proceeding to Step 3.
```
**Fixes**: Q1 failure in Scenario B (completes the fix from Change A).

### Change C — Step 3: sequential context freshness
```diff
  Choose the lightest executor that reliably satisfies the item's difficulty; when in doubt, use more capable.
+
+ For sequential items: construct context immediately before dispatch — re-read write set and read set files from disk after preceding items complete. Do not build all sequential contexts upfront; earlier items' outputs must be reflected in later items' file content.
```
**Fixes**: Q2 stale-context failure for write-read and write-write sequential chains.

### Change D — Step 4: spec compliance semantics
```diff
- Check: report completeness, spec compliance (Summary matches Todo intent), write set adherence, verification PASS, and discoveries.
+ Check: report completeness, spec compliance (actual changes match Todo intent — use Summary as entry point, verify directly against write set content if Summary is ambiguous or partial), write set adherence, verification PASS, and discoveries.
```
**Fixes**: Q3 quality gap where plausible Summary could mask wrong actual changes.

### Change E — Step 2: plan summary scope definition
```diff
- Each subagent receives: plan summary, single Todo item, write set with file content, read set with file content, and verification method.
+ Each subagent receives: plan summary (objective, constraints, and architectural decisions relevant to this item only — not other items' status or unrelated context), single Todo item, write set with file content, read set with file content, and verification method.
```
**Fixes**: Q2 borderline in Scenario C; prevents "plan summary" rationalization for including excess context.

---

## 批注区
