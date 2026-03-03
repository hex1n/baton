## Baton — Shared Understanding Construction Protocol

Write lock: source code writes require `<!-- BATON:GO -->` in plan.md. Markdown is always writable.
Remove `<!-- BATON:GO -->` to roll back to the annotation cycle.

### Flow
Scenario A (clear goal): research.md → human states requirement → plan.md → annotation cycle → generate todo → BATON:GO → implement
Scenario B (exploration): research.md ← annotation cycle → plan.md ← annotation cycle → generate todo → BATON:GO → implement
Simple changes may skip research.md.

### Annotation Protocol
Human adds annotations in research.md or plan.md. AI responds to each, records in ## Annotation Log:
- `[NOTE]` additional context → incorporate, explain how it affects conclusions
- `[Q]` question → answer with file:line evidence
- `[CHANGE]` request modification → if problematic, explain with evidence + offer alternatives, let human decide
- `[DEEPER]` not deep enough → continue investigation in specified direction
- `[MISSING]` something omitted → investigate and supplement
- `[RESEARCH-GAP]` needs more research → pause current document, do research, then return

**The human is not always right.** When there's a problem, explain with evidence, offer alternatives. Final decision is the human's.

### Rules
- No source code before BATON:GO. NEVER add BATON:GO yourself
- plan.md does not contain a todolist. Append ## Todo only after human says "generate todolist"
- Every annotation must be responded to + recorded in Annotation Log
- Only modify files in the plan; propose additions (file + reason) in plan first
- Same approach fails 3× → stop and report
- Discover omission during implementation → stop, update plan.md, wait for human confirmation
- When all items complete, remind to archive to plans/

### Session handoff
- Stopping mid-work → append ## Lessons Learned to plan.md (what worked / what didn't / what to try next)
- When archiving, preserve Lessons Learned and Annotation Log (long-term reference)

### Parallel sessions (optional)
- Use git worktrees: each session gets its own working copy
- BATON_PLAN for different plan files: `BATON_PLAN=plan-auth.md`