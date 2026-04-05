**Question**: What is the baton project — its architecture, components, design philosophy, and how everything fits together?
**Depth**: Deep
**Key finding**: Baton is a portable, protocol-first AI coding agent collaboration framework that enforces a closed-loop state machine with file-based artifacts, hook-driven runtime enforcement, and multi-host adapter support.
**Open questions**: 3 — see end of document

---

# Baton Project Deep Analysis

## 1. Overview

Baton is a **portable harness protocol** for AI-assisted coding tasks. It
defines a structured collaboration loop between AI agents and humans, where
each phase produces file-based artifacts, human gates enforce critical
decisions, and runtime hooks prevent protocol violations.

```
┌──────────────────────────────────────────────────────────────┐
│                    BATON ARCHITECTURE                        │
│                                                              │
│  spec/protocol/     ← Portable protocol (tool-agnostic)     │
│  spec/adapters/     ← Host-specific mapping (CC/Codex/...)   │
│  spec/bootstrap/    ← Shell scripts (install, hooks, lib)    │
│  spec/templates/    ← Artifact templates (en/zh)             │
│  spec/profiles/     ← Repo-type profiles (java/node/python)  │
│  spec/extensions/   ← Stack-specific overlays (java-strict)  │
│  skills/            ← Role skill definitions (canonical)     │
│  .claude/skills/    ← Runtime skill entrypoints (symlinked)  │
│  .agents/           ← Agent definitions (symlinked)          │
│  .harness/          ← Per-task artifacts + control plane     │
│  tests/             ← Shell-based test suite                 │
└──────────────────────────────────────────────────────────────┘
```

- **Version**: 1.0.0
- **Created**: 2026-02-27 (first commit)
- **Commits**: 225 as of 2026-04-04
- **Language**: Pure shell (bash) runtime; markdown + YAML artifacts
- **Size**: ~4,352 lines of shell code in bootstrap; ~12 skill definitions

✅ Verified: all from direct file reads and git log in this session.

---

## 2. Core Design Philosophy

Six principles from `spec/README.md`:

1. **Protocol is primary** — the spec is tool-agnostic; specific agent CLIs are just execution adapters
2. **Repo-specific knowledge in profiles** — not in the protocol core
3. **Multi-agent preferred, sequential valid** — graceful degradation
4. **Verification is first-class** — Gate 3 blocks code generation until the validation path is proven executable
5. **`task-status.md` is the minimum control plane** — everything else is a convenience layer
6. **Extensions add strictness** — heavier behavior (e.g., Java runtime validation) lives in extensions, not the core

---

## 3. State Machine

The heart of baton is a 10-state finite state machine with a linear happy path and explicit repair loops:

```
exploring → specifying → architecting → awaiting_human_arch
  → verification_check → generating → reviewing
  → ready_for_human_close → complete
```

Any state can transition to `blocked`. Blocked states must be categorized:
`verification_blocker`, `scope_blocker`, `environment_blocker`, or `design_blocker`.

### Gates (Quality Checkpoints)

| Gate | Before | Enforces |
|------|--------|----------|
| G1: Scoped Exploration Complete | Specifier | Entry points, write surface, test points, risks |
| G2: Architecture Approved | Verification | Requirements ↔ architecture consistent; **human approval** |
| G3: Verification Path Check | Generator | Validation commands executable, isolation declared |
| G4: Independent Review | Human Close | evaluation.md exists with verdict |
| G5: Human Close | Complete | **Human confirms** objective met |

Two of five gates are human-mandatory (G2, G5). The protocol physically cannot bypass them — the `pre-transition` hook checks for `human_ack: true` in State Notes before allowing transitions from `awaiting_human_arch` or `ready_for_human_close`.

✅ Verified: `spec/bootstrap/hooks/pre-transition:88-92`

---

## 4. Role System

### 4.1 Role Skills (State-Machine Phases)

| Skill | Role Token | Isolation | Primary Artifact |
|-------|-----------|-----------|-----------------|
| `baton-explorer` | `scoped-explorer` | `context: fork` | `exploration.md` |
| `baton-specifier` | `specifier` | inline | `requirements.md` |
| `baton-architect` | `architect` | inline | `architecture.md` |
| `baton-verifier` | `verification-explorer` | `context: fork` | `verification.md` |
| `baton-generator` | `generator` | inline | code changes |
| `baton-evaluator` | `evaluator` | `context: fork` | `evaluation.md` |

Three roles (`explorer`, `verifier`, `evaluator`) declare `context: fork`, meaning they **must** run in isolated contexts (separate Agent invocations) to prevent contamination from prior reasoning. In `strict` mode, inability to isolate is a blocker.

### 4.2 Capability Skills (Non-State-Machine)

| Skill | Purpose |
|-------|---------|
| `baton-clarifier` | Pre-state-machine requirement interviewing |
| `baton-orchestrator` | One-command entry point that drives the full flow |
| `baton-status` | Report current task state and next action |
| `baton-retrospective` | Post-completion process lessons |
| `deep-research` | Systematic investigation (this skill) |
| `first-principles-planner` | Strategic planning |

### 4.3 Orchestrator

The `baton-orchestrator` is the most sophisticated skill (~700 lines). It:

1. **Phase 0**: Triages clarity (Vague/Partial/Clear) and risk (Low/Medium/High)
2. **Phase 1-9**: Drives each role skill in sequence
3. **Risk-Adaptive Matrix**: Adjusts phase depth per risk level (e.g., Low skips Codex review; High requires delivery order in architecture)
4. **Codex Integration**: Optionally uses `codex:rescue` for cross-model review at Medium/High risk
5. **Draft Recovery**: On resume, detects draft artifacts and re-runs the interrupted phase
6. **Repair Loops**: Routes evaluator BLOCKED verdicts back through generator + re-evaluation

✅ Verified: `skills/baton-orchestrator/SKILL.md`

---

## 5. Artifact System

All task state lives in `.harness/` as markdown/YAML files:

| Artifact | Writer | Purpose |
|----------|--------|---------|
| `exploration.md` | Explorer | Task-local code understanding |
| `requirements.md` | Specifier | Implementation contract |
| `architecture.md` | Architect | Change design with tradeoffs |
| `verification.md` | Verifier | Proof that validation is executable |
| `evaluation.md` | Evaluator | Independent review verdict |
| `task-status.md` | All roles | Control plane (state, owner, notes) |
| `retrospective.md` | Retrospective | Process lessons |
| `clarification-brief.md` | Clarifier | Pre-SM requirement interview output |
| `escalation.md` | Generator | Escalation for design-level issues |

### `task-status.md` Schema

```
| Scope | Owner | State | Eval Round | Updated At | Notes |
```

Plus structured `## State Notes` section with machine-readable keys:
`risk_level`, `artifact_language`, `codex_available`, `human_ack`, `base_commit`, etc.

Plus `## Transition Log` table auto-populated by the `post-artifact` hook.

### Bilingual Support

Templates exist in both English (`spec/templates/`) and Chinese (`spec/templates/zh/`). Language is configured via `profile.local.yaml` → `documentation.artifact_language`. `task-status.md` always stays in English as the portable control plane.

✅ Verified: template directories and `spec/README.md:196-206`

---

## 6. Runtime Enforcement (Hooks)

The most distinctive technical feature of baton is its **hook-based runtime enforcement**. Hooks are shell scripts that intercept agent tool calls and block protocol violations in real-time.

### Hook Architecture

```
.claude/settings.json
  ├── PreToolUse (Write|Edit|MultiEdit) → hooks/pre-transition
  ├── PostToolUse (Write|Edit|MultiEdit) → hooks/post-artifact
  ├── Stop → hooks/stop-check
  ├── SubagentStop (baton-evaluator|baton-verifier) → hooks/subagent-stop
  └── SessionStart (startup|resume) → hooks/session-start
```

All hooks share `hooks/lib/parse-input.sh` which:
- Reads JSON from stdin (Claude Code hook protocol)
- Detects host type (`cc` or `codex`) from input shape
- Provides `hook_pass()` / `hook_block()` control flow
- Reads profile values from `profile.local.yaml`
- Manages transition cache in `/tmp/baton-transition-*`

### Hook Behaviors

| Hook | Trigger | What It Enforces |
|------|---------|-----------------|
| `pre-transition` | Before writing `task-status.md` | Valid state transitions only; `human_ack` required for human gates; draft artifacts block phase advancement; blocked state requires categorized notes |
| `post-artifact` | After writing any `.harness/*.md` | Artifact schema validation; transition logging; `human_ack` auto-clear after gate passage |
| `stop-check` | Session end | Required artifacts present for current state; isolation provenance valid |
| `subagent-stop` | Verifier/Evaluator agent completes | Verifier must have written `verification.md`; Evaluator state must be reviewing/blocked/ready; eval round counter incremented; max round enforcement |
| `session-start` | Session start/resume | Injects harness context |

### Reentrance Guard

`BATON_HOOK_ACTIVE=1` prevents hooks from firing during hook-initiated writes (e.g., when `post-artifact` clears `human_ack` or logs transitions). This is a simple but critical mechanism.

✅ Verified: `parse-input.sh:4` checks `BATON_HOOK_ACTIVE`

### Cross-Host Support

Hooks work on both Claude Code (via `.claude/settings.json`) and Codex (via `.codex/hooks.json`). The `parse-input.sh` detects host type from input shape — `file_path` present = CC, `command` present = Codex. Windows support uses `run-hook.cmd` which locates Git Bash and delegates.

✅ Verified: `parse-input.sh:40-48`, `run-hook.cmd`

---

## 7. Bootstrap / Distribution System

### Installation Flow

```
install-harness.sh ─── vendors baton payload into target repo
  └── .vendor/baton-harness/     (full spec/ copy)
  └── .harness/harness.lock.yaml (version truth)
  └── .harness/overrides/        (local customization slots)
  └── .claude/skills/            (materialized runtime skills)
  └── .agents/                   (materialized agent definitions)
  └── install-hooks.sh           (registers hooks in settings.json)

init-harness.sh ────── bootstraps .harness/ directory
  └── copies templates
  └── seeds profile.local.yaml
  └── materializes CLAUDE.md + AGENTS.md from governance template
  └── optionally registers first task

start-task.sh ──────── registers a task row in task-status.md

update-harness.sh ──── updates vendored payload from newer baton checkout
```

### Skill Distribution

In the baton repo itself, skills live in `skills/` and are **symlinked** into `.claude/skills/` and `.agents/` by `link-skills.sh`. For external repos, skills are **copied** during `install-harness.sh`. The `.link-mode` file tracks which mode is active.

### Governance Entrypoints

`CLAUDE.md` and `AGENTS.md` are **generated** from `spec/templates/root-governance.template.md` via `sync-governance-entrypoints.sh`. This ensures Claude Code, Codex, and Cursor all see the same repo-level governance rules.

✅ Verified: `install-harness.sh`, `link-skills.sh`, `.agents/` directory (all symlinks)

---

## 8. Validation Infrastructure

### Bootstrap Validators

| Script | Purpose |
|--------|---------|
| `validate-transition.sh` | Checks if state A → B is allowed |
| `validate-artifact.sh` | Validates artifact schema (required sections) |
| `validate-isolation.sh` | Checks isolation provenance in verifier/evaluator artifacts |
| `validate-state-artifacts.sh` | Ensures required artifacts exist for current state |
| `check-consistency.sh` | Comprehensive consistency check (~656 lines) — cross-validates owners.txt, states.txt, skill definitions, templates, hooks, and running config |

`check-consistency.sh` is the most substantial script, running ~20+ invariant checks including:
- Owner tokens in skills match `owners.txt`
- States in `states.txt` match `state-machine.md`
- Skill frontmatter declares correct `context: fork`
- Template required sections match `artifact-schema.md`
- Hook commands in settings.json are correct
- Provenance block fields are consistent

✅ Verified: `check-consistency.sh:1-80`

### Test Suite

15 test scripts in `tests/`:

```
test-harness-context.sh      test-hook-session-start.sh
test-hook-parse-input.sh     test-hook-stop-check.sh
test-hook-post-artifact.sh   test-hook-subagent-stop.sh
test-hook-pre-transition.sh  test-install-hooks.sh
test-hook-run-hook.sh        test-prepare-review.sh
test-skill-links.sh          test-start-task.sh
test-task-status.sh          test-validate-artifact.sh
test-validate-isolation.sh   test-validate-state-artifacts.sh
test-validate-transition.sh
```

Tests create temporary directories, mock harness state, and verify hook/validator behavior. Pure shell — no test framework dependency.

---

## 9. Multi-Host Adapter System

Baton is designed to work across three AI coding environments:

| Host | Entrypoint | Sub-Agent Isolation | Hooks |
|------|-----------|-------------------|-------|
| Claude Code | `CLAUDE.md` | `Agent` tool | `.claude/settings.json` |
| Codex | `AGENTS.md` | `spawn_agent(fork_context: false)` | `.codex/hooks.json` |
| Cursor | `AGENTS.md` | Manual chat separation | Limited (user discipline) |

### Isolation Policy

Two modes:

- **`strict`**: Verifier and Evaluator must have true context isolation. Sequential fallback = blocker.
- **`compat`**: Sequential fallback allowed but must be explicitly recorded in artifact provenance (isolation mode, execution context, fallback reason).

The adapter contract (`cli-adapter-interface.md`) defines what the adapter **may** and **may not** change. Adapters can customize prompts and invocation style, but cannot change canonical states, required gates, or isolation semantics.

✅ Verified: `cli-adapter-interface.md`, `claude-code.md`, `codex.md`, `cursor.md`

---

## 10. Extension System

### Java Backend Strict Extension

Located at `spec/extensions/java-backend-strict/`, this is the only extension currently. It adds:

- Module-by-module generation loops
- Runtime evaluator with three verification layers
- Additional artifacts: `codebase-map.md`, `decisions.md`, `api-contract.yaml`
- Explicit migration and escalation checkpoints

The original design (`spec/11.md`) was a comprehensive Java multi-agent harness written in Chinese — the extension extracts its stricter workflow as an overlay on top of the portable core.

### Profiles

Three repo-type profiles defined:

| Profile | Target | Key Signals |
|---------|--------|-------------|
| `java-maven.yaml` | Java/Maven projects | `pom.xml`, `src/main/java` |
| `node-monorepo.yaml` | Node monorepos | `package.json`, `pnpm-workspace.yaml` |
| `python-service.yaml` | Python services | `pyproject.toml`, `pytest.ini` |

Profiles define verification style, workspace strategy, high-risk surfaces, preferred test layers, and example commands. They inform skills about repo-specific conventions.

---

## 11. Completed Task History

The `.harness/task-status.md` shows 19 completed tasks — all internal baton development work:

1. `add-version-flag` — version flag feature
2. `protocol-consistency-fix` — protocol alignment fixes
3. `harness-workflow-improvements` — workflow hardening
4. `harness-language-support` — bilingual artifact support
5. `harness-distribution-installer` — install/update/lockfile system
6. `root-readme-bilingual` — bilingual README
7. `root-readme-standardization` — bilingual checks
8. `governance-multi-host-entrypoints` — AGENTS.md + shared template
9. `runtime-thickness-improvements` — cross-platform isolation
10. `isolation-enforcement-hardening` — strict/compat semantics
11. `provenance-standardization-hardening` — shared provenance contract
12. `positioning-protocol-vs-runtime` — positioning documentation
13. `workflow-best-practice-doc` — workflow documentation
14. `runtime-enforcement-hardening` — hook system hardening (had 1 eval round!)
15. `bootstrap-structure-rationalization` — structure cleanup

The project uses itself (dogfooding) — baton's own development is tracked through the baton harness.

---

## 12. Architecture Diagram

```
                         ┌─────────────────┐
                         │   User Request   │
                         └────────┬────────┘
                                  │
                         ┌────────▼────────┐
                         │  Orchestrator   │ ← baton-orchestrator
                         │ (Phase 0-9)     │
                         └────────┬────────┘
                                  │
          ┌───────────────────────┼───────────────────────┐
          │                       │                       │
    ┌─────▼─────┐          ┌─────▼─────┐          ┌─────▼─────┐
    │  Phase 1   │          │  Phase 2   │          │ Phase 3-4  │
    │ Clarifier  │          │  Explorer  │          │ Specifier/ │
    │ (inline)   │          │ (isolated) │          │ Architect  │
    └────────────┘          └────────────┘          │ (inline)   │
                                                    └─────┬─────┘
                                                          │
                                                    ┌─────▼─────┐
                                                    │  HUMAN     │
                                                    │  GATE G2   │
                                                    └─────┬─────┘
                                                          │
    ┌─────────────┐          ┌─────────────┐        ┌─────▼─────┐
    │  Phase 7    │          │  Phase 6    │        │  Phase 5   │
    │ Evaluator   │◄─────── │  Generator  │◄───────│  Verifier  │
    │ (isolated)  │          │  (inline)   │        │ (isolated) │
    └──────┬──────┘          └─────────────┘        └────────────┘
           │                        ▲
           │ BLOCKED ───────────────┘  (repair loop)
           │
    ┌──────▼──────┐
    │  HUMAN      │
    │  GATE G5    │
    └──────┬──────┘
           │
    ┌──────▼──────┐
    │  Complete   │
    └─────────────┘

    ─── Runtime Enforcement Layer ───

    ┌─────────────────────────────────────────────┐
    │  Hooks (pre-transition, post-artifact,      │
    │         stop-check, subagent-stop,           │
    │         session-start)                       │
    │  Validators (transition, artifact, isolation,│
    │             state-artifacts, consistency)    │
    └─────────────────────────────────────────────┘
```

---

## 13. Key Design Tensions & Trade-offs

### 13.1 Protocol Portability vs Runtime Depth

Baton explicitly chose **protocol-first** positioning. The shell scripts are a "reference runtime" — the real value is the protocol spec (state machine, gates, artifacts). This means:

- **Pro**: Any AI agent CLI can adopt baton by implementing the adapter interface
- **Con**: Runtime enforcement is limited to what shell hooks can intercept; deeper enforcement (e.g., preventing an agent from reasoning about prior context) requires host support

### 13.2 File-Based Control Plane

Everything lives in markdown files, not a database or API:

- **Pro**: Zero infrastructure dependency; works in any git repo; human-readable; version-controlled
- **Con**: Parsing markdown tables in shell is fragile (see TODOS.md mentioning sidecar YAML migration if parsing gets complex)

### 13.3 Isolation via Host Mechanisms

Context isolation (critical for Verifier/Evaluator independence) depends entirely on the host's sub-agent capabilities:

- **Claude Code**: `Agent` tool provides true isolation
- **Codex**: `spawn_agent(fork_context: false)` provides isolation
- **Cursor**: Manual discipline only — acknowledged weakness

### 13.4 Dogfooding Tension

The project uses itself for development, which creates a chicken-and-egg dynamic — hook changes can block the implementation of those very changes (noted in user's feedback memories).

---

## 14. Source Audit

| Claim | Source | How obtained |
|-------|--------|-------------|
| Version 1.0.0 | `spec/VERSION` | Read in session |
| 225 commits | `git log --oneline --all \| wc -l` | Run in session |
| First commit 2026-02-27 | `git log --reverse --format='%ai' \| head -1` | Run in session |
| 10 canonical states | `spec/protocol/state-machine.md:3-13` | Read in session |
| 5 gates defined | `spec/protocol/gates.md` | Read in session |
| 3 isolated roles (explorer, verifier, evaluator) | Skill YAML frontmatter `context: fork` | Read in session |
| 19 completed tasks | `.harness/task-status.md` | Read in session |
| ~4,352 lines of shell in bootstrap | `wc -l` output | Run in session |
| 15 test scripts | `tests/` directory listing | Read in session |
| Hook reentrance guard via BATON_HOOK_ACTIVE | `parse-input.sh:4` | Read in session |
| human_ack enforcement in pre-transition | `pre-transition:88-92` | Read in session |
| Based on Anthropic harness design | `README.md:12` | Read in session |

---

## 15. Open Questions

1. **Production adoption count**: How many external repos have adopted baton via `install-harness.sh`? The task history is all self-development. No evidence of external adoption metrics. ❓ Unknown — no telemetry or adoption tracking visible.

2. **Windows runtime coverage**: The TODOS and residual risks mention no live Windows smoke test for `run-hook.cmd`. The `.cmd` bridge exists but has only been tested at the command-generation level. ❓ Unverified Windows runtime behavior.

3. **Profile enforcement**: TODOS.md notes "profile-based risk behavior enforcement" as DEFERRED. Profiles currently inform skills via documentation hints, but no hook validates that a skill's behavior matches the profile's expectations at runtime.

---

## 16. Weakest Conclusion

The claim that baton's hook system provides "runtime enforcement" is accurate but should be understood narrowly: hooks can block file writes that violate protocol (invalid transitions, malformed artifacts, missing human acknowledgment), but they cannot enforce behavioral constraints like "the evaluator must not have seen the generator's reasoning." That deeper isolation guarantee depends entirely on host capabilities, and in `compat` mode it relies on self-reporting honesty in artifact provenance blocks.
