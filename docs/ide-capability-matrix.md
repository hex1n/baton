# IDE Capability Matrix

As of 2026-03-11. Baton supports 4 IDEs across 3 protection tiers.

## Product Tiers

| Tier | Hosts | Hooks | Write-lock | Key gaps |
|------|-------|-------|------------|----------|
| **Full protection** | Claude Code, Factory | 8/8 | Hard block | None |
| **Core protection** | Cursor | 5/8 | Hard block (via adapter) | No write-set drift warning, no session-end reminders, no retrospective enforcement |
| **Rules guidance** | Codex | 2/8 experimental | None | Advisory-only SessionStart/Stop hooks; no PreToolUse write-lock or write-set enforcement |

## Hook Inventory

Which hooks fire for each host:

| Hook | Event | Enforcement | Claude Code | Factory AI | Cursor IDE | Codex |
|------|-------|-------------|-------------|------------|------------|-------|
| write-lock.sh | PreToolUse | Hard block | ✅ | ✅ | ✅ adapter | ❌ |
| phase-guide.sh | SessionStart | Advisory | ✅ | ✅ | ✅ | ✅ experimental |
| bash-guard.sh | PreToolUse | Advisory | ✅ | ✅ | ✅ | ❌ |
| subagent-context.sh | SubagentStart | Advisory | ✅ | ✅ | ✅ | ❌ |
| pre-compact.sh | PreCompact | Advisory | ✅ | ✅ | ✅ | ❌ |
| post-write-tracker.sh | PostToolUse | Advisory | ✅ | ✅ | ❌ | ❌ |
| stop-guard.sh | Stop | Advisory | ✅ | ✅ | ❌ | ✅ experimental |
| completion-check.sh | TaskCompleted | Soft block | ✅ | ✅ | ❌ | ❌ |

Source: `setup.sh` IDE installation logic.

## Cursor Notes

- Write-lock runs through `adapter-cursor.sh`, which translates shell exit codes to Cursor's JSON protocol (`{"decision":"allow"}` / `{"decision":"deny","reason":"..."}`).
- Missing hooks mean Cursor users get no advisory warning for plan-unlisted writes, no session-end discipline, and no retrospective enforcement. These behaviors are still described in workflow.md but are not technically prompted.

## Codex Notes

- Codex currently exposes experimental `SessionStart` and `Stop` hooks. Baton configures them through `.codex/hooks.json` and `adapter-codex.sh`.
- Those hooks are advisory only. Codex still has no `PreToolUse` write-lock, no post-write drift warning, and no task-completion gate.
- `setup.sh` enables the project-level `codex_hooks` feature flag and adds a per-project trust entry in `~/.codex/config.toml`.
- `AGENTS.md` and `.agents/skills/` remain part of the Codex path so the workflow still loads even when hooks are unavailable.
- Codex sandbox and human approval controls provide separate safety layers outside Baton's scope.

## Maintenance Rules

1. Update this matrix before changing supported-IDE wording in `README.md`, `setup.sh`, or installer-facing tests.
2. If product capability and Baton installer target differ, describe both explicitly instead of collapsing them into one label.
3. When a host adds or removes hook support, update the Hook Inventory table and re-evaluate the Product Tiers section.
