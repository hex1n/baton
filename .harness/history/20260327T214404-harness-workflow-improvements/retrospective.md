# Retrospective: harness-workflow-improvements

## 1. Outcome

- Closed as: `complete`
- Main blocker: no design blocker remained after implementation; the only residual verification gap was local environment availability for `pwsh`
- Human decision: accepted the residual risk that `start-task.ps1` was updated but not runtime-executed in this environment

## 2. What Worked

- Retrospective-driven scope tightening worked well. The changes stayed focused on the actual failure modes from the prior task instead of expanding into a broader harness rewrite.
- Treating Requirements Sync as a Gate 2 checklist item, not a new canonical state, fixed the handoff ambiguity without increasing state-machine complexity.
- Moving state validation to `spec/protocol/states.txt` followed the same single-source-of-truth pattern that had already worked for `owners.txt`.
- Fixing `sync-skills.sh` against actual filesystem state paid off immediately in the current workspace: the script correctly detected that `.link-mode` said `symlink` while the repo actually contained ordinary copies.
- Adding concrete Codex `spawn_agent({ fork_context: false })` / `wait_agent(...)` examples closed the gap between policy and operator practice.
- Splitting the public flow description into Happy Path and Repair Loops made the protocol easier to read without changing canonical semantics.

## 3. What Failed

- The initial public docs made the harness look more linear than it really is. The repair loop still existed in the state machine, but README-level wording hid it.
- PowerShell runtime verification was not possible in this environment because `pwsh` is unavailable. Cross-platform parity for `start-task.ps1` therefore remains a reviewed-but-not-executed assumption.
- One documentation grep command briefly used shell-unsafe quoting and had to be rerun. The content was correct; the verification command was not.

## 4. Repo-Specific Lessons

- In this repo, `.claude/skills/` and `.agents/` are currently plain copies, not symlinks or hardlinks, even though `.link-mode` declares `symlink`. Tooling must inspect reality, not intent metadata.
- Mirrored skill copies are common enough in this workspace that `sync-skills.sh` should be treated as a normal verification step after skill changes, not a rare recovery tool.
- Detailed Codex execution guidance belongs in `spec/adapters/codex.md`; README should stay high-level and point there.

## 5. Harness Lessons

- The harness should present a linear happy path for readability and explicit repair loops for correctness. Mixing those two concepts into one line makes the protocol look simpler than it is.
- `blocked` is the protocol's loop primitive. The loop was never removed; it just needed clearer presentation.
- Verifier and Evaluator are the high-value isolation points. Early-phase roles can remain same-session when artifacts are explicit and handoffs are disciplined.
- Requirements Sync belongs to gate semantics, not state proliferation. A checklist rule was enough once the docs, skills, and verification path all enforced it.

## 6. Standardization Candidates

- Keep `owners.txt` and `states.txt` as the default pattern for any future machine-readable protocol token sets.
- Keep one adapter-level section with concrete sub-agent spawn/wait examples for each supported multi-agent runtime instead of scattering long examples across README and skills.
- Keep public protocol docs in a two-layer format:
  - one-line happy path for orientation
  - explicit repair-loop bullets or diagrams for operational truth
- Treat `check-consistency.sh` plus mirrored-skill sync verification as standard Gate 3 preflight in this repo.
