# IDE Capability Matrix

As of 2026-03-11. Baton supports 4 IDEs across 3 protection tiers.

## Product Tiers

| Tier | Hosts | Hooks | Write-lock | Key gaps |
|------|-------|-------|------------|----------|
| **Full protection** | Claude Code, Factory | 8/8 | Hard block | None |
| **Core protection** | Cursor | 5/8 | Hard block (via adapter) | No write-set drift warning, no session-end reminders, no retrospective enforcement |
| **Rules guidance** | Codex | 0/8 | None | No technical enforcement of any kind. Relies on AGENTS.md + AI self-discipline |

## Hook Inventory

Which hooks fire for each host:

| Hook | Event | Enforcement | Claude Code | Factory AI | Cursor IDE | Codex |
|------|-------|-------------|-------------|------------|------------|-------|
| write-lock.sh | PreToolUse | Hard block | ✅ | ✅ | ✅ adapter | ❌ |
| phase-guide.sh | SessionStart | Advisory | ✅ | ✅ | ✅ | ❌ |
| bash-guard.sh | PreToolUse | Advisory | ✅ | ✅ | ✅ | ❌ |
| subagent-context.sh | SubagentStart | Advisory | ✅ | ✅ | ✅ | ❌ |
| pre-compact.sh | PreCompact | Advisory | ✅ | ✅ | ✅ | ❌ |
| post-write-tracker.sh | PostToolUse | Advisory | ✅ | ✅ | ❌ | ❌ |
| stop-guard.sh | Stop | Advisory | ✅ | ✅ | ❌ | ❌ |
| completion-check.sh | TaskCompleted | Soft block | ✅ | ✅ | ❌ | ❌ |

Source: `setup.sh` IDE installation logic (claude/factory: lines 907-962, cursor: lines 964-1002).

## Cursor Notes

- Write-lock runs through `adapter-cursor.sh`, which translates shell exit codes to Cursor's JSON protocol (`{"decision":"allow"}` / `{"decision":"deny","reason":"..."}`).
- Missing hooks mean Cursor users get no advisory warning for plan-unlisted writes, no session-end discipline, and no retrospective enforcement. These behaviors are still described in workflow.md but are not technically prompted.

## Codex Notes

- Codex has no custom hook system. Baton injects rules via generated `AGENTS.md` and `.agents/skills/` directory.
- All enforcement in Codex is protocol-only: the AI reads the rules and follows them (or doesn't). There is no technical interception.
- Codex sandbox and human approval controls provide separate safety layers outside Baton's scope.

## Maintenance Rules

1. Update this matrix before changing supported-IDE wording in `README.md`, `setup.sh`, or installer-facing tests.
2. If product capability and Baton installer target differ, describe both explicitly instead of collapsing them into one label.
3. When a host adds or removes hook support, update the Hook Inventory table and re-evaluate the Product Tiers section.
