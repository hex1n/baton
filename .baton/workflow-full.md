## AI Workflow (plan-first)

Source writes blocked until plan.md has `<!-- BATON:GO -->`.
Flow: research → plan.md → annotate → <!-- BATON:GO --> → implement
Place `<!-- BATON:GO -->` at the top of plan.md. Moving or deleting it re-locks writes.

### [RESEARCH] Research Phase
> Skip this section if plan.md already exists.

If plan.md exists from a previous task, archive first:
`mkdir -p plans && mv plan.md plans/plan-$(date +%Y-%m-%d)-topic.md`

Deeply read relevant code — implementations, call chains, data flow.
Write findings to `research.md` with file:line evidence for every claim.
Mark inferences as `Inference:`. List unknowns as `Open Questions:`.

For non-trivial tasks (3+ files or unfamiliar area), structure research.md:
1. **Scope** — what's in, what's explicitly out
2. **Architecture** — call chains, data flow (file:line refs)
3. **Constraints** — what can't change and why
4. **Existing patterns** — naming, error handling, testing conventions
5. **Risks** — what could go wrong, historical issues
6. **Key files** — every file relevant, with why
7. **Coverage** — N/M relevant files read

Bug fix shortcut (1-2 files): Error | Reproduction | Root Cause | Fix Scope | Regression Risk

Context management: 10+ files → use subagents, write findings to research.md

### [PLAN] Plan Phase
> Skip this section if plan.md contains `<!-- BATON:GO -->`.

Based on research, write `plan.md` citing research.md findings:
- Declare scope: files to modify + importers to verify
- Include code snippets for non-trivial changes
- Verification: concrete test cases (input → expected output), not "run tests"
  Specify WHICH tests and WHY they cover the change
- Rollback: what to do if implementation goes wrong

Self-review before human annotation:
"3 biggest risks?" / "Files outside scope that could break?" / "What would a senior engineer question?"
→ Add ## Risks section to plan.md

Before adding BATON:GO, check:
- [ ] Every file change has concrete verification (input → expected output)
- [ ] Importers and callers of modified code are identified
- [ ] Risks section exists with rollback strategy
- [ ] No open questions remain unresolved

Do NOT add todo checklist — wait for human review.
I'll annotate, you address notes and update plan. Repeat until approved.
When I say "add todo", append detailed task checklist (which file, what change, how to verify).

### [IMPLEMENT] Implement Phase
> Only active after `<!-- BATON:GO -->` is added by the human.

- Consider /compact before starting (clear research context from window)
- 10+ file changes → start fresh session (plan.md = handoff doc)
- Implement todo items in order
- After each item: typecheck/build → mark `[x] ✅`
- After ALL items: full test suite, note result at bottom
- If session ends mid-implementation, checklist is the handoff document
- Rollback: checkpoints first, git revert for permanent
- If stopping mid-implementation, append "## Lessons Learned" (what worked / didn't / next)
- Don't stop until everything is complete

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
