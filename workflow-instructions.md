## AI Workflow (plan-first)

This project uses a plan-first workflow. Source code writes are blocked until `plan.md` contains `<!-- GO -->`.

### Flow

**1. Research**
If plan.md already exists (leftover from a previous task), archive it first: rename to `plans/plan-{date}-{topic}.md` (create `plans/` dir if needed).

Then deeply read the relevant code. Not file names — read implementations, trace call chains, understand data flow. Write findings to `research.md` with file:line evidence for every factual claim.

For non-trivial tasks (touching 3+ files or unfamiliar areas), structure research.md with these sections (empty sections are a red flag — fill them or explain why N/A):

1. **Scope** — what's in, what's explicitly out
2. **Architecture** — call chains, data flow (with file:line references)
3. **Constraints** — what can't change and why
4. **Existing patterns** — naming, error handling, testing conventions
5. **Risks** — what could go wrong, historical issues
6. **Key files** — every file relevant to this task, with why

For small changes (1-2 files, well-understood area), a focused research.md without the full template is fine — depth should match task complexity.

**2. Plan**
Based on your research, write `plan.md` — cite research.md findings where possible:
- What files to change, how, and why
- Include code snippets for non-trivial changes
- Verification: how to prove it works, how to prove it doesn't break existing behavior
- Rollback: what to do if implementation goes wrong (if applicable)
- Do NOT add a todo checklist yet — wait for review

**3. Annotate**
I'll add inline notes to `plan.md`. When you see them: address every note, update the plan accordingly, and do not implement. This cycle repeats until I'm satisfied.

**4. Todo**
When I say "add todo", append a detailed task checklist to `plan.md`. Each item: which file, what change, how to verify. Each item should be 5-15 minutes of work.

**5. Implement**
I'll add `<!-- GO -->` to `plan.md` to unlock source code writes. Then:
- Implement todo items in order
- After each item: run typecheck/build to catch type errors, then mark it: `- [x] Step N: description ✅ typecheck pass`
- After ALL items complete: run full test suite, note result at the bottom of the checklist
- If session ends mid-implementation, the checklist is the handoff document for the next session
- Don't stop until everything is complete

### Rules
- Before `<!-- GO -->` appears, do not write any source code (markdown files are fine)
- NEVER add `<!-- GO -->` to plan.md yourself — only the human adds this marker. If you discover AI has added it, remove it immediately and return to the Annotate phase
- During implementation, only modify files explicitly mentioned in the plan. If you discover a file that needs changing but isn't in the plan, stop and report it — don't silently add it to scope
- Do not add things to the plan that weren't discussed
- Do not add unnecessary comments, jsdoc, or type `any`
- If the plan has a problem, stop and tell me — don't silently deviate
- If an approach fails, note it briefly in the relevant TODO item before trying an alternative. This prevents future sessions from repeating failed attempts
- If something fails after 3 attempts, stop and report instead of retrying
- When I say "revert", use git to undo changes, then try a narrower approach
