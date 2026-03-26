# Baton Harness

A portable AI coding agent collaboration protocol with a Claude Code reference implementation.

Based on [Anthropic's harness design for long-running apps](https://www.anthropic.com/engineering/harness-design-long-running-apps).

## Structure

```
spec/              Portable harness protocol (tool-agnostic)
.claude/skills/    Claude Code role skills (reference implementation)
CLAUDE.md          Governance summary loaded into every conversation
```

## Protocol

The protocol defines a closed loop for AI-assisted coding tasks:

**Explorer** → **Specifier** → **Architect** → human approval → **Verifier** → **Generator** → **Evaluator** → human close

Each role produces file-based artifacts in `.harness/`. State is tracked in `module-status.md`.

See [spec/README.md](spec/README.md) for the full portable protocol.

## Quick Start

### Adopt in a new repo

```bash
# Bootstrap .harness/ directory with templates
spec/bootstrap/init-harness.sh --repo-root /path/to/repo --profile auto --adapter claude-code

# Start a task
spec/bootstrap/start-task.sh --repo-root /path/to/repo --task-id my-task
```

### Copy role skills to target repo

```bash
cp .claude/skills/harness-*.md /path/to/repo/.claude/skills/
```

## Role Skills

| Skill | Role | Gate |
|-------|------|------|
| `harness-explorer` | Code exploration (repo + scoped) | Scoped Exploration Complete |
| `harness-specifier` | Requirements specification | — |
| `harness-architect` | Technical architecture | Architecture Approved (human) |
| `harness-verifier` | Verification path check | Verification Path Check |
| `harness-generator` | Code implementation | — |
| `harness-evaluator` | Independent evaluation | Independent Review |

## Capability Skills

| Skill | Purpose |
|-------|---------|
| `deep-research` | Systematic investigation of code, APIs, docs |
| `first-principles-planner` | Strategic planning from first principles |
