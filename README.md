# Baton Harness

A portable AI coding agent collaboration protocol with a Claude Code reference implementation.

Based on [Anthropic's harness design for long-running apps](https://www.anthropic.com/engineering/harness-design-long-running-apps).

## Structure

```
spec/              Portable harness protocol (tool-agnostic)
.claude/skills/    Claude Code role skills (reference implementation)
CLAUDE.md          Root governance entrypoint for Claude Code style hosts
AGENTS.md          Root governance entrypoint for Codex / Cursor style hosts
```

## Protocol

The protocol defines a closed loop for AI-assisted coding tasks:

Happy path:

**Explorer** → **Specifier** → **Architect** → human approval → **Verifier** → **Generator** → **Evaluator** → human close

Repair loops:

- `Verifier BLOCKED` → back to `Architect` / `Specifier`
- `Generator BLOCKED` → back to `Architect` / `Specifier` / `Human`
- `Evaluator BLOCKED` → back to `Generator`, then re-run `Evaluator`

Each role produces file-based artifacts in `.harness/`. State is tracked in `task-status.md`.

Two operating rules matter in practice:

- After architecture approval, sync `requirements.md` to any approved
  architecture decisions that change requirements-level truth before
  verification begins.
- Run `spec/bootstrap/check-consistency.sh` as the protocol preflight before
  or during `verification_check`.

> **Display name → runtime token mapping** (used in `start-task.sh --owner`):
> Explorer = `repo-explorer` / `scoped-explorer` | Specifier = `specifier` | Architect = `architect` |
> Verifier = `verification-explorer` | Generator = `generator` | Reviewer = `reviewer` |
> Evaluator = `evaluator` | Human = `human`

See [spec/README.md](spec/README.md) for the full portable protocol.

## Quick Start

### Adopt in a new repo

```bash
# Install vendored harness payload into the target repo
spec/bootstrap/install-harness.sh --repo-root /path/to/repo

# Then bootstrap from the vendored spec inside the target repo
/path/to/repo/.vendor/baton-harness/spec/bootstrap/init-harness.sh --repo-root /path/to/repo --profile auto --adapter claude-code

# Start a task
/path/to/repo/.vendor/baton-harness/spec/bootstrap/start-task.sh --repo-root /path/to/repo --task-id my-task
```

`init-harness` also materializes shared root governance into `CLAUDE.md` and
`AGENTS.md`, so Claude Code, Codex, and Cursor can see the same repo-level
rules.

If you run the harness in Codex, launch `Verifier` and `Evaluator` as isolated
sub-agents with `fork_context: false`. Copy-paste examples for `spawn_agent`
and `wait_agent` live in [spec/adapters/codex.md](spec/adapters/codex.md).

### Install / Update In Target Repo

Recommended external-repo flow:

```bash
# First install
spec/bootstrap/install-harness.sh --repo-root /path/to/repo

# Later update the same repo to the current baton checkout
spec/bootstrap/update-harness.sh --repo-root /path/to/repo
```

On Windows, use the same `.sh` entrypoints from Git Bash, or invoke them from
PowerShell with `bash spec/bootstrap/<command>.sh ...`. Baton does not keep a
separate `spec/bootstrap/*.ps1` business-entrypoint layer.

This creates:

- `.vendor/baton-harness/` as the vendored upstream payload
- `.harness/harness.lock.yaml` as the version truth
- `.harness/overrides/skills/` and `.harness/overrides/templates/` for local customization
- `.claude/skills/` and `.agents/` as runtime skill entrypoints materialized from vendor + overrides
- root `CLAUDE.md` and `AGENTS.md`, materialized by `init-harness` from the shared governance template

### Link skills for development (baton repo only)

After cloning, skill files are regular copies. Run `link-skills.sh` to upgrade them to
symlinks so edits in `skills/` propagate automatically:

```bash
# Rebuild .claude/skills/ and .agents/ from canonical skills/
spec/bootstrap/link-skills.sh
```

This applies to `.claude/skills/` and `.agents/` directories. Run after any
change to `skills/` if you are in copy mode. When symlinks are used, their
targets are written as repo-relative paths so the checkout stays portable.
`sync-skills.sh` inspects the
actual workspace file state; it does not trust `.link-mode` alone.

### Manual Copy Fallback

```bash
cp .claude/skills/baton-*.md /path/to/repo/.claude/skills/
```

Prefer `install-harness` / `update-harness` for normal adoption. Manual copy is
only the low-friction fallback.

For baton maintainers, update root governance in
`spec/templates/root-governance.template.md`, then run:

```bash
bash spec/bootstrap/sync-governance-entrypoints.sh --repo-root . --force
```

## Role Skills

| Skill | Role | Gate |
|-------|------|------|
| `baton-explorer` | Code exploration (repo + scoped) | Scoped Exploration Complete |
| `baton-specifier` | Requirements specification | — |
| `baton-architect` | Technical architecture | Architecture Approved (human) |
| `baton-verifier` | Verification path check | Verification Path Check |
| `baton-generator` | Code implementation | — |
| `baton-evaluator` | Independent evaluation | Independent Review |

## Capability Skills

| Skill | Purpose |
|-------|---------|
| `deep-research` | Systematic investigation of code, APIs, docs |
| `first-principles-planner` | Strategic planning from first principles |
