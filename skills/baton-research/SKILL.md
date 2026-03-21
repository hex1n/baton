---
normative-status: Authoritative specification for the RESEARCH phase.
name: baton-research
description: >
  Use when the user needs to understand how something works across multiple
  files or modules before making changes — tracing behavior chains, comparing
  alternatives, reconciling contradictions, or building evidence-backed
  understanding. Trigger on: "research", "investigate", "understand how X
  works", "trace the behavior", "compare approaches", "what are the
  tradeoffs", "I need to understand before deciding", cross-module behavior
  questions, contradictory evidence that needs resolution, or [PAUSE]
  annotations. Also use for external research (docs, APIs, ecosystem).
  Do NOT use for: single-file questions, quick lookups, explaining one
  function, implementing approved plans, or reviewing code.
user-invocable: true
---

## Iron Law

```text
NO CONCLUSIONS WITHOUT EXPLICIT EVIDENCE
NO SOURCE CODE CHANGES DURING RESEARCH — INVESTIGATE ONLY
VERIFY = VISIBLE OUTPUT. "I checked" is not evidence.
FIRST PRINCIPLES BEFORE FRAMING.
```

This skill is the local source of truth for research-phase framing and evidence handling.
Cross-phase invariants are in `constitution.md`.

Research produces understanding, not code. Write findings down for the plan phase.

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This conclusion is obvious, no evidence needed" | Obvious ≠ correct. Find evidence or mark ❓ |
| "I can answer from what I already know" | Memory is unreliable. Verify with evidence |
| "I've investigated enough already" | Did you write Self-Challenge? Shallow = skipped |
| "The counterexample sweep found nothing" | Did you actively search, or just not find any by default? |
| "I found several blog posts confirming this" | Blogs are leads, not evidence. Trace to primary source |

## Gotchas

> Operational failure patterns observed in real usage.

1. **Investigation moves become formulaic.** The 4-field move template
   (Question/Checked/Found/Status) is a floor, not a ceiling. When a move
   naturally produces a comparison table or architecture diagram, use that
   format. Forcing everything into the template buries the signal.
   *(Observed: eval agents produced rigid move-by-move output even when a
   single comparison table would have been clearer.)*

2. **Missing boundary behavior lists.** When investigating a hook or API,
   the most valuable findings are often edge cases (empty input, missing
   files, error states). Without explicit prompting, these get scattered
   across moves instead of collected in one place.
   *(Observed: baseline outputs listed behavioral edge cases as bullet
   points; with-skill outputs embedded them in moves where they were harder
   to find.)*

3. **Small tasks trigger full process.** Before the Sizing Gate was added,
   a single-file investigation produced 204 lines with Frame/Orient/
   Self-Challenge — 2x the baseline's 95 lines, with no quality improvement.
   *(Observed in eval-2 iteration-1. Fixed by adding Sizing Gate + Light Path.)*

## When to Use

- Medium/Large tasks requiring cross-module behavior tracing
- Ambiguous or contradictory requirements needing evidence-backed clarification
- Multi-surface consistency checks (N IDEs, N API endpoints, N config formats)
- Root-cause analysis across multiple execution paths
- Design analysis: framework comparison, architecture evaluation
- External research: documentation, API, ecosystem investigation
- User says "research" or "deep research"
- After `[PAUSE]` annotation

**When NOT to use**: Quick lookups, single-file explanations, Trivial tasks
(see constitution.md §Task Sizing).

**Trigger heuristics**:
- Crosses 2+ modules AND requires reconstructing a behavior chain → use
- Contradictory evidence sources or requirement statements → use
- Comparing 2+ approaches/frameworks/design axes → use
- Verification requires multi-step strategy or designed test scenarios → use
- Only need to explain single file/function/concept → don't use

## Sizing Gate

Assess task size **before** choosing the process path. The sizing determines
how much structure is warranted — not whether evidence discipline applies
(evidence markers always apply).

| Size | Signal | Process Path |
|------|--------|-------------|
| **Small** | 1-2 files, single question, one verification step | **Light path**: investigate → findings document. No Frame/Orient/Self-Challenge/Counterexample Sweep. Keep output under 100 lines. |
| **Medium** | 2+ modules, behavior chain, multi-step verification | **Standard path**: Frame (3 fields) → Orient → Investigate → Self-Challenge (brief) → Review → Convergence |
| **Large** | Design verification, multi-env, manual judgment needed | **Full path**: Frame (all fields) → Orient → Investigate → Self-Challenge (full format) → Review → Convergence |

When in doubt, size up. But **do not size up reflexively** — a task that
touches one file and answers one question is Small regardless of how
interesting the file is.

The sizing decision itself is evidence: state which signal you observed.

## Two-Phase Mode + Review Gate

When analysis has already been done in chat (comparison tables, code examples,
conclusions), the skill's role shifts from **process guide** to **quality
checklist**. Do not rewrite existing analysis into the template — enhance it.

**Phase 1 — Free exploration** (before invoking this skill):
Use any method: chat exploration, brainstorming skill, parallel agents.
Goal: produce the richest possible analysis.

**Phase 2 — Framework enhancement** (this skill):
Take Phase 1 output and enhance with this checklist:
- [ ] Problem framed? (Step 0) — if not, add framing
- [ ] Evidence marked? (`✅` verified / `❓` unverified) — if not, mark key claims
- [ ] ≥2 independent evidence methods used? (Step 2) — if not, note gap
- [ ] Counterexample sweep done? (Step 3) — if not, do it now
- [ ] Self-Challenge written? (Step 5) — if not, write it
- [ ] Config files compared field-by-field? — if research involves config files, verify

**Review gate**:
Dispatch baton-review for context-isolated independent review. This catches
gaps that self-enhancement misses.

**Anti-pattern**: Do NOT rewrite Phase 1 analysis to fit Move 1/Move 2 format.
Preserve the original structure. The checklist adds missing elements — it does
not restructure existing content.

---

## Light Path (Small tasks)

For Small tasks: investigate directly, write a concise findings document.
The value of this skill for Small tasks is **evidence discipline only** —
mark claims with ✅/❓, reference specific files and lines.

**Output structure** (aim for under 100 lines):

```
# <Topic>

## Question
<What is being investigated and why>

## Findings
<Direct investigation results with evidence markers>
<Reference specific files:lines>

## False Positive / Edge Case Surfaces (if applicable)
<Where issues might arise>

## 批注区
```

No Frame/Orient/Self-Challenge/Counterexample Sweep/Questions for Human Judgment.
Just answer the question with evidence.

---

## Standard + Full Path (Medium/Large tasks)

### Step 0: Frame the Investigation

**Medium** — 3 fields:
- **Question**: what exactly is being investigated — frame as *behavior or outcome*, not as mechanism or assumed solution
- **Why**: what later decision this supports
- **Scope / Out of scope**: boundaries

**Large** — add these fields:
- **Known constraints**: repo, platform, tooling
- **System goal being served**: what outcome this research enables
- **Claimed framing**: the framing as stated by human/docs
- **Assumptions to validate**: what must be verified before accepting that framing

Framing examples:
- ❌ "How does the pre-commit hook call baton?" (assumes the mechanism; forecloses alternatives)
- ✅ "What triggers governance checks when a git commit is made?" (behavior-neutral; keeps alternatives open)

### Step 1: Orient

Assess starting position. This determines strategy and template.

**Familiarity**: **none** / **partial** / **deep**
- none/partial → build baseline first (System Baseline or Source Landscape in template). Do not skip.
- deep → state existing understanding in 3-5 sentences. Proceed to investigation.

**Evidence type**: **codebase-primary** / **external-primary** / **mixed**
- Codebase-primary → use `./template-codebase.md`
- External-primary → use `./template-external.md`
- Mixed → primary type's template + supplementary section

**Strategy statement**: one paragraph describing how investigation will proceed.

### Step 2: Investigation Methods

Use ≥2 independent evidence acquisition methods. Record what you used and why sufficient.

- **Strong independence**: code reading + runtime verification; official docs + actual API response
- **Moderate**: grep + targeted file read; official docs + versioned release notes
- **Weak**: two similar searches — two weak methods don't count

If constrained to single source, state why and compensate with deeper cross-checks.

### Step 3: Investigate

**Start with an overview before diving in.** When investigating a system or
subsystem, first produce a brief architecture sketch (ASCII diagram, layered
list, or data flow) showing the components and their relationships. This
anchors the investigation and makes the output immediately scannable. Then
dive into the details.

Drive by the most blocking uncertainty, not by fixed categories.

At each point:
1. What is the most important thing I still do not know?
2. What evidence would reduce that uncertainty?
3. What investigation move would produce that evidence?
4. Did it reduce uncertainty enough, or change direction?

Use whatever move fits: trace behavior, test claims, compare alternatives, resolve
contradictions, build systematic coverage, probe assumptions. AI already knows how
to investigate code — the value of this skill is in constraining the failure modes below.

**Output format guidance:**
- Use **tables** for comparisons (N items × M dimensions). Prose comparisons
  bury the signal.
- Use **bullet lists** for behavioral edge cases and boundary conditions.
  Don't scatter these across moves — collect them in one place per component.
- Use **narrative** for causation chains and design rationale.
- After investigating a hook, API, or subsystem, list its **boundary behaviors**
  (what happens at edges: empty input, missing files, multiple matches,
  error states). These are often the most valuable findings.

**AI failure modes to guard against:**

1. **Only positive evidence** — actively search for disproving evidence before converging.
   "Nothing contradicted it" is not a counterexample sweep.
2. **Claims without visible evidence** — every material claim needs ✅ (how verified)
   or ❓ (why not). "I checked" is not evidence.
3. **Smoothing over contradictions** — when sources disagree, name the contradiction
   explicitly. Do not merge into vague prose. Apply conflict resolution rules
   (constitution.md §Evidence).
4. **Premature convergence** — if an explanation "seems obvious," that's when you
   need counterexample sweep most. Search for evidence that would disprove it.
5. **Config files treated as code** — when research involves config files
   (hooks.json, settings.json, plugin.json), they need field-by-field
   comparison, not logic-flow analysis. A single field value difference
   (e.g., `matcher`) can be the most impactful finding.

**When direction changes**, record: previous uncertainty, new uncertainty, why the
switch, what the new line is expected to clarify.

**If multiple dimensions exist**, decompose them explicitly before investigating.
Name each, state why distinct, preserve reconciliation step before conclusions.

**Minimum record per investigation move:**
- Question/uncertainty addressed
- What was checked → what was found
- Status: ✅ / ❌ / ❓
- What remains unresolved

The move format is a minimum, not a straitjacket. If a move naturally produces
a comparison table, a signal flow diagram, or a behavioral edge-case list,
use that format instead of forcing everything into the 4-field template.

**Synthesis**: when multiple moves used, reconcile before conclusions — where
findings reinforce, where in tension, what remains unresolved.

**Counterexample sweep** (before forming conclusions):

**Medium** — one paragraph: state the leading interpretation, name one thing you
checked that could have disproved it, and the result.

**Large** — full active search:
- State the leading interpretation
- What disproving evidence was sought
- What was checked → result
- Effect on confidence

**Active search requirement** (Large only): "Found no contradictions" only passes if you name:
1. The specific artifact, code path, or document section you checked for a bypass or failure
2. What the contradiction *would have looked like* if present
3. That you *specifically went looking* — not merely that you didn't encounter it

❌ Passive: "Counterexample sweep: no evidence found contradicting this conclusion."
✅ Active: "Leading interpretation: hook always runs on commit. Searched for: env-var bypass flag and `--no-verify` passthrough in `hooks.json` and `install.sh`. Found: neither. If `SKIP_BATON=1` were honored, conclusion would be false. Confidence: high, but git's own `--no-verify` at the command level remains unexamined."

### Step 4: Evidence Standards

Mark material claims: `✅` verified (state how) / `❓` unverified (state why).

Micro-examples — state *how*, not just that you did:
- ✅ `read hooks.json:12–18` — not `✅ verified`
- ✅ `ran test suite; output in §Test Results` — not `✅ tested`
- ❓ `no runtime access — cannot verify execution order` — not `❓ unverified`
- ❓ `official docs don't state this; inferred from source code` — not `❓ assumed`

Conflict resolution: see constitution.md §Evidence (including combination examples).

Preserve evidence provenance per move. Do not merge findings so aggressively that
the original evidence path becomes unclear.

### Step 5: Self-Challenge

**Medium** — write 2-3 sentences at the end of the research document:
what's the weakest conclusion, what would disprove it, what did you skip?

**Large** — write `## Self-Challenge` into the research artifact with full format:

1. What's the weakest conclusion and why? What evidence would disprove it?
2. What did I NOT investigate that I should have?
3. What assumptions did I make without verifying?

Shallow answers ("no other alternatives" / "all assumptions verified") signal
that self-challenge was not genuine. Fix before presenting.

**Required format for Q1** (weakest conclusion, Large only) — must include all four fields:
- **Conclusion**: [exact claim as stated in conclusions]
- **Why weakest**: [specific reason — what gap in evidence makes you least confident]
- **Falsification condition**: If [specific, observable thing] were true or present, this conclusion would be wrong
- **Checked for it**: [what you specifically searched, and what you found]

❌ Shallow: "Weakest: the hook always fires. Disproof: I found no evidence against this."
✅ Specific: "Weakest: the hook runs unconditionally on every commit. Why: I only traced the install path, not bypass surfaces. Falsification: if `git commit --no-verify` silently skips the hook. Checked: confirmed git itself supports `--no-verify`; whether baton's hook registration respects this flag was not verified (❓)."

### Step 6: Review

1. **Dispatch** baton-review via Agent tool (context isolation):
   - Codebase-primary → `./review-prompt-codebase.md`
   - External-primary → `./review-prompt-external.md`
   - Fallback: self-review using the matching review prompt checklist
2. **Process findings**: accept with fix, reject with evidence, or keep as ❓
3. **Re-review** if materially rewritten
4. **Repeat** until passes or circuit breaker (3 cycles → escalate to human)

### Step 7: Convergence

Before transitioning to plan:
1. Mark superseded conclusions: `→ Revised in [section]`
2. Write One-Sentence Summary, Final Conclusions, Questions for Human Judgment
3. Capture chat requirements: `Human requirement (chat): ...`
4. Reconcile multiple investigation moves before final conclusions

## Exit Criteria

1. Main path verified with evidence, no ❓ on critical paths
2. Key unknowns explicitly marked ❓ with reason
3. Human judgment questions with blocking severity
4. Every conclusion classifies plan implication: actionable / watchlist / judgment-needed / blocked
5. Open unknowns classified: blocks plan / does not block plan

## Output

Default path: `baton-tasks/<topic>/research.md`. `mkdir -p` the target directory.

**Template**: determined by Orient — codebase-primary or external-primary.
**Small tasks**: use Light Path structure directly (no template file needed).

**Update policy**:
- Same investigation → update in place, mark superseded with `→ Revised in [section]`
- After `[PAUSE]` → append new findings, reconcile before handoff
- After BLOCKED (implementation escalated back to research) → read any research supplement added by baton-debug (if present); append new findings as a named section (e.g., `## Findings: BLOCKED Escalation`); mark affected prior conclusions superseded; reconcile before handoff to plan phase.
- New investigation on same topic → archive old file, create fresh research.md

Preserve traceability when conclusions change.

## Annotation Protocol

Every research document ends with the content of `.baton/annotation-template.md`.
Follow using-baton Annotation Protocol for processing rules.
