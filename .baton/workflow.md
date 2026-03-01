## AI Workflow (plan-first)

Source writes blocked until plan.md has `<!-- BATON:GO -->`.
Flow: research → plan.md → annotate → <!-- BATON:GO --> → implement
Place `<!-- BATON:GO -->` at the top of plan.md. Moving or deleting it re-locks writes.
Phase-specific guidance is provided automatically at session start.

### Rules
- Before `<!-- BATON:GO -->`, do not write source code (markdown is fine)
- NEVER add `<!-- BATON:GO -->` yourself — only the human adds this marker
- Only modify files in the plan; propose additions (file + reason), wait for confirmation
- Do not add things to the plan that weren't discussed
- If the plan has a problem, stop and tell me — don't silently deviate
- Same approach fails 3× → stop and report instead of retrying
- "revert" → git undo, then narrower approach

### Session handoff
- If stopping mid-implementation, append to plan.md:
  ## Lessons Learned
  - What worked / What didn't / What to try next
- When archiving plan.md → plans/, keep lessons section (future reference)

### Parallel sessions (optional)
- Use git worktrees: each session gets its own working copy
- BATON_PLAN for different plan files: `BATON_PLAN=plan-auth.md`
