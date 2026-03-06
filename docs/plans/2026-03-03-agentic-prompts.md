# Agentic Prompt Improvement Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Baton's AI-facing prompts more agentic — giving AI clear execution strategies and thinking postures, not just rules and goals.

**Architecture:** Three-layer improvement: workflow.md (always-loaded mindset + rules), phase-guide.sh (per-phase execution strategies), workflow-full.md (complete reference synced with above). Control mechanisms (write-lock, bash-guard) remain unchanged.

**Root Problem:** Current prompts are declarative ("what the rules are") but not procedural ("how to execute well"). AI defaults to surface-level research, blind compliance on annotations, and sloppy implementation because prompts don't establish the right thinking posture.

---

## Task 1: Improve workflow.md — Add Mindset + Refine Rules

**Files:**
- Modify: `.baton/workflow.md`

**Problem:** All rules are negative ("No X", "NEVER Y") with no framing for WHY. AI follows rules mechanically without understanding the underlying principles. No guidance on thinking posture.

**Changes:**

Add a `### Mindset` section at the top (after title, before Flow) establishing three core principles:

```markdown
### Mindset
You are an investigator, not an executor. Your job is to surface what you know,
challenge what seems wrong, and ensure nothing is hidden from the human.

Three principles that override all defaults:
1. **Verify before you claim** — "should be fine" is not evidence. Read the code, cite file:line.
2. **Disagree with evidence** — the human is not always right. When you see a problem,
   explain it with code evidence. Don't comply silently, don't hide concerns.
3. **Stop when uncertain** — if you don't understand something, say so. Don't guess, don't gloss over.
```

Refine annotation descriptions to be more action-oriented:

| Annotation | Current | Improved |
|------------|---------|----------|
| `[Q]` | "answer with file:line evidence" | "answer with file:line evidence. Read code first — don't answer from memory" |
| `[CHANGE]` | "if problematic, explain with evidence + offer alternatives" | "verify safety first — check callers, tests, edge cases. If problematic, explain with evidence + offer alternatives" |
| `[DEEPER]` | "continue investigation in specified direction" | "your previous work was insufficient. Investigate seriously in the specified direction" |

**Verification:** Token count should stay under ~600 tokens (current ~400, adding ~150 for mindset + ~50 for annotation refinements).

---

## Task 2: Improve phase-guide.sh — Execution Strategies Per Phase

**Files:**
- Modify: `.baton/phase-guide.sh`

**Problem:** Each phase outputs 2-3 lines of what to produce, but zero guidance on HOW to do it well. This is the highest-impact change.

### Phase: RESEARCH (current ~50 tokens → target ~250 tokens)

**Current:**
```
📍 RESEARCH phase — produce research.md
Read code deeply, trace call chains to implementations (don't stop at interfaces).
Mark risks: ✅ confirmed safe / ❌ problem found / ❓ unverified. Attach file:line to every conclusion.
Simple changes may skip research and go straight to plan.md.
```

**Improved:**
```
📍 RESEARCH phase — produce research.md

You are investigating code you have never seen. Your goal: build understanding
deep enough that the human can judge whether you truly comprehend the system.

Execution strategy:
1. Identify entry points relevant to the task (human's request or affected files)
2. For each function/method call, read the IMPLEMENTATION — not just the interface
3. When a call delegates to another layer, follow it. Stop only at:
   framework internals, stdlib, or external deps (annotate WHY you stopped)
4. Use subagents to trace parallel branches when you find 3+ call paths (10+ files)

For every conclusion in research.md:
- Attach file:line evidence. No evidence = mark as ❓ unverified
- "Should be fine" is NOT a valid conclusion — verify or mark ❓
- Mark risks: ✅ confirmed safe / ❌ problem found / ❓ unverified

Simple changes may skip research and go straight to plan.md.
```

### Phase: PLAN (current ~50 tokens → target ~200 tokens)

**Current:**
```
📍 PLAN phase — produce plan.md (based on research.md + requirements)
Include: what (referencing research), why, impact scope, risk mitigation.
Approach analysis: extract constraints → derive 2-3 approaches (feasibility + pros/cons) → recommend + reasoning.
Do NOT write todolist — generate only after human approves.
```

**Improved:**
```
📍 PLAN phase — produce plan.md (based on research.md + requirements)

Don't jump to "how to do it". Derive your approach from research findings:
1. Extract hard constraints from research.md (architecture limits, dependencies,
   backward compatibility, performance, team conventions)
2. Derive 2-3 approaches. For each:
   - Feasibility: ✅ feasible / ⚠️ risky / ❌ not feasible (with file:line evidence)
   - Pros and cons (analyzed against each constraint)
   - Impact scope (files touched, callers affected)
3. Recommend one + reasoning that traces back to specific research findings

If research revealed fundamental design problems:
- Present honestly: "file:line shows X, which means Y"
- Offer both: patch within existing structure vs. fix root problem
- State clearly: this is an architectural decision the human must make

Do NOT write todolist — generate only after human says "generate todolist".
```

### Phase: ANNOTATION (current ~50 tokens → target ~250 tokens)

**Current:**
```
📍 ANNOTATION cycle — plan.md awaiting approval
Human may add annotations: [NOTE] [Q] [CHANGE] [DEEPER] [MISSING] [RESEARCH-GAP]
Respond to each annotation, record in Annotation Log.
Human annotations may not always be correct — explain issues with file:line evidence, offer alternatives.
Human will say "generate todolist" or add <!-- BATON:GO --> when satisfied.
```

**Improved:**
```
📍 ANNOTATION cycle — plan.md awaiting approval

Read the document carefully. Look for new annotations:
[NOTE] [Q] [CHANGE] [DEEPER] [MISSING] [RESEARCH-GAP]

For EACH annotation, BEFORE responding:
- [Q]: Don't answer from memory. Go read the actual code, then answer with file:line.
- [CHANGE]: Verify the change is safe first. Check callers, check tests, check edge cases.
  If you find a problem, say so with evidence — don't comply just because the human asked.
- [DEEPER]: Your previous work was insufficient. This is a signal to investigate seriously,
  not just add a paragraph.
- [RESEARCH-GAP]: Pause other annotations. Do the research. Append findings to research.md
  as ## Supplement. Then return.

Record every response in ## Annotation Log with:
- The annotation type and section
- Your response with file:line evidence
- The outcome (accepted / rejected / awaiting human decision)

The human is not always right. Your job is to surface what you know.
Blind compliance is a failure mode. So is hiding concerns.
Human will say "generate todolist" or add <!-- BATON:GO --> when satisfied.
```

### Phase: IMPLEMENT (current ~30 tokens → target ~200 tokens)

**Current:**
```
📍 IMPLEMENT phase — <!-- BATON:GO --> is set
Implement in Todo order. After each item: typecheck → mark [x].
After all items: run full test suite. Discover omission → stop, update plan, wait for confirmation.
```

**Improved:**
```
📍 IMPLEMENT phase — <!-- BATON:GO --> is set

For each todo item, follow this sequence:
1. Re-read the plan section for this item — understand WHAT and WHY
2. Read the target files before modifying — understand current state
3. Implement the change
4. Run typecheck/build. If it fails, fix before moving on
5. Mark [x] only AFTER verification passes

Quality checks:
- Only modify files listed in the plan. Need a new file? Stop, update plan, wait for confirmation
- Discover something the plan didn't anticipate? STOP. Update plan.md, wait for human confirmation
- Same approach fails 3 times? Stop and report — don't keep trying

After ALL items complete: run full test suite, record results at bottom of plan.md.
Todo items with dependencies: execute sequentially. Independent items: may run in parallel.
```

### Phase: ARCHIVE (unchanged)

Keep current archive reminder as-is — it's already clear.

---

## Task 3: Improve workflow-full.md — Sync + Strengthen

**Files:**
- Modify: `.baton/workflow-full.md`

**Changes:**

1. **Add Mindset section** at the top (same as workflow.md Task 1) — ensures the mindset is in the complete reference even when not loaded as context

2. **Update [RESEARCH] section** — add execution strategy matching phase-guide improvements:
   - Add "Execution strategy" numbered list
   - Add explicit "what counts as evidence" guidance
   - Strengthen "depth tips" with more specific instructions

3. **Update [ANNOTATION] section** — add thinking posture per annotation type:
   - Add "For EACH annotation, BEFORE responding" block (matching phase-guide)
   - Strengthen "Core Principles for AI Responses" with the verify-first pattern
   - Add explicit anti-pattern: "Don't answer [Q] from memory — read the code"

4. **Update [IMPLEMENT] section** — add per-item execution sequence:
   - Add the 5-step sequence (re-read plan → read target → implement → verify → mark)
   - Add "Quality checks" section

5. **Update annotation protocol descriptions** — same refinements as workflow.md:
   - `[Q]`: add "read code first"
   - `[CHANGE]`: add "verify safety first"
   - `[DEEPER]`: add "your previous work was insufficient"

**Verification:** workflow-full.md must remain a superset of workflow.md. All content in workflow.md must appear (verbatim or expanded) in workflow-full.md.

---

## Task 4: Update Tests

**Files:**
- Modify: `tests/test-phase-guide.sh`
- Modify: `tests/test-workflow-consistency.sh` (if needed)

**Changes:**

Update test assertions to match new phase-guide output. Key new keywords to verify:

| Phase | New keywords to assert |
|-------|----------------------|
| RESEARCH | "entry points", "IMPLEMENTATION", "evidence", "unverified" |
| PLAN | "constraints", "2-3 approaches", "Feasibility", "todolist" |
| ANNOTATION | "BEFORE responding", "verify", "Annotation Log", "not always right" |
| IMPLEMENT | "Re-read the plan", "target files", "typecheck", "STOP" |

Run `tests/test-workflow-consistency.sh` to verify workflow.md and workflow-full.md shared content stays in sync.

---

## Task 5: Verify All Tests Pass

**Steps:**
1. Run `bash tests/test-phase-guide.sh`
2. Run `bash tests/test-workflow-consistency.sh`
3. Run `bash tests/test-write-lock.sh` (should be unaffected)
4. Run `bash tests/test-stop-guard.sh` (should be unaffected)
5. Fix any failures

---

## Summary of Changes

| File | Change Type | Impact |
|------|------------|--------|
| `.baton/workflow.md` | Add mindset, refine annotations | Always-loaded context gets thinking posture |
| `.baton/phase-guide.sh` | Expand all 4 phases | Per-session guidance becomes actionable strategies |
| `.baton/workflow-full.md` | Sync + strengthen | Complete reference stays consistent |
| `tests/test-phase-guide.sh` | Update assertions | Tests match new output |
| `.baton/write-lock.sh` | No change | — |
| `.baton/stop-guard.sh` | No change | — |
| `.baton/bash-guard.sh` | No change | — |

## Design Decisions

**Why not make workflow.md longer?** workflow.md is always loaded (~every API call). The mindset section adds ~150 tokens — acceptable for the value. Execution strategies stay in phase-guide (loaded once per session).

**Why not add more to write-lock messages?** Write-lock is a technical enforcement. Its messages are already effective. Adding agentic content there would be noise — the AI already knows the rules from workflow.md.

**Why expand phase-guide so much?** phase-guide is injected ONCE at session start. The cost is one-time per session. The benefit is significant: AI gets a clear execution strategy for the entire session. This is the highest ROI change.

**English vs Chinese?** English prompts per user preference. This also keeps consistency with the existing English workflow.md and phase-guide output.