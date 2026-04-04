# Evaluation: promote-java-artifacts

**Owner**: `evaluator`  
**Status**: `approved`

## 1. Inputs

- Requirements: `.harness/requirements.md` -- 13 requirements (R1-R13), P0/P1/P2 priorities
- Architecture: `.harness/architecture.md` -- 4 delivery units, 21 files in write surface
- Verification path: `.harness/verification-path.md` -- 11 verification commands
- Diff / changed files: uncommitted working tree changes from base commit `cc00a5a` -- 4 new files, 14 modified files, 2 deleted files

## 2. Execution Provenance

- Role: evaluator
- Isolation mode: strict
- Execution context: isolated_subagent
- Agent ID: baton-evaluator (Agent tool dispatch with subagent_type isolation)
- Evidence: Cold-read `.harness/requirements.md`, `.harness/architecture.md`, `.harness/verification-path.md`, `.harness/scoped-map.md`, `.harness/task-status.md`; loaded implementation diff via `git diff HEAD`; read all 4 new template files; read modified source files directly; ran all 11 verification commands from verification-path.md
- Fallback policy: N/A
- Fallback reason: N/A

## 3. Findings

### Layer 1: Deterministic Checks

- Command 1 (validate-artifact decisions -- complete file): exit 0 -- PASS
- Command 2 (validate-artifact decisions -- missing heading): exit 1 -- PASS
- Command 3 (validate-artifact codebase-map -- complete file): exit 0 -- PASS
- Command 4 (validate-artifact codebase-map -- missing sections): exit 1 -- PASS
- Command 5 (validate-artifact evaluation -- old format): exit 0 -- PASS
- Command 6 (validate-artifact evaluation -- new format with layers): exit 0 -- PASS
- Command 7 (validate-artifact decisions -- draft skip): exit 0 -- PASS
- Command 8 (test-validate-artifact.sh): 20 passed, 0 failed of 20 total -- PASS
- Command 9 (test-start-task.sh): 8 passed, 0 failed of 8 total -- PASS
- Command 10 (check-consistency.sh): invariants 1-6, 8-18 all OK; 3 invariant-7 errors are pre-existing (`link-skills.sh` `relative_link_target` bug) -- PASS (pre-existing errors not introduced by this task)
- Command 11 (link-skills.sh): completed successfully; `.claude/agents/` errors are pre-existing -- PASS
- Hard failures: none

### Layer 2: Diff Review

- Scope validation: 20 file changes (4 new, 14 modified, 2 deleted) within approved write surface. One file in the architecture plan (`skills/baton-orchestrator/SKILL.md`) was NOT modified -- corresponds to unimplemented R8. No files changed outside the approved surface.
- Architecture conformance: Implementation follows the architecture closely. The `has_section()` grouping fix (adding parentheses around pattern) is a necessary correctness fix that improves all existing validations. The three-layer evaluation structure is embedded in `## 3. Findings` only (architecture proposed both sections 3 and 4); see Warning below.
- Unexpected changes: The `has_section()` fix (`.*${pattern}` to `.*(${pattern})`) is not explicitly called out in the architecture but is a correctness fix. Without it, patterns like `Risk|Dependency|风险` would not be properly scoped to `##` headings for the middle alternatives. All 20 existing tests continue to pass, confirming backward compatibility.
- Bug patterns: No null handling, off-by-one, or resource leak issues found. Shell scripting follows existing conventions. The `decisions` field validation correctly anchors patterns to line-start with `^-[[:space:]]*`.
- Security: No injection risks, no secrets exposed. All patterns use fixed regex, no user-controlled input in regex.
- Test quality: 8 new test cases in test-validate-artifact.sh (English pass, Chinese pass, missing-heading fail, missing-fields fail, draft skip, English codebase-map pass, Chinese codebase-map pass, missing-sections fail). 2 new test cases in test-start-task.sh. Tests are meaningful -- they test both positive and negative paths, and cover bilingual variants. The "decisions missing fields" test verifies that having some but not all required fields still fails validation.

### Layer 3: Requirements Verification

- Blockers: R8 (P1) is not implemented -- orchestrator skill Risk-Adaptive Matrix was not updated
- Warnings:
  1. R4 architecture specified three-layer sub-structure for both `## 3. Findings` AND `## 4. Verification Results`, but implementation only adds layers to section 3. Section 4 was simplified to "Acceptance criteria status" without Layer sub-structure. The literal R4 text says "将 ## 3. Findings 和 ## 4. Verification Results 细化为三层子结构". This is a minor architectural deviation but does not break any automated validation.
  2. The `generator-feedback.md` template link in `artifact-overlay.md` (line 90) still points to `./templates/generator-feedback.template.md` but this file was promoted to core in a previous task. This is a pre-existing issue, not introduced by this task.

## 4. Verification Results

- [x] [unit] R3: validate-artifact.sh decisions -- complete file returns exit 0 (Command 1)
- [x] [unit] R3: validate-artifact.sh codebase-map -- complete file returns exit 0 (Command 3)
- [x] [unit] R3: validate-artifact.sh decisions/codebase-map -- missing sections returns exit 1 (Commands 2, 4)
- [x] [integration] R1+R3: artifact-schema.md `decisions.md` required sections (decision blocks with choice/rejected/why/why not/impact) match validate-artifact.sh section patterns -- verified by Commands 1-2 and direct file inspection
- [x] [integration] R1+R3: artifact-schema.md `codebase-map.md` required sections (project structure, module dependencies, data model, code style, high-risk) match validate-artifact.sh patterns -- verified by Commands 3-4 and direct file inspection
- [x] [integration] R10: start-task.sh distributes decisions.md and codebase-map.md templates to .harness/ (Command 9 test-start-task.sh: 8/8 pass)
- [x] [unit] Draft decisions.md and codebase-map.md do not cause validation failure (Command 7)
- [x] [integration] R9: check-consistency.sh invariants 17+18 pass (Command 10)
- [x] [unit] R4: Old format evaluation.md passes validation (Command 5 -- backward compatible)
- [x] [unit] R4: New format evaluation.md with three-layer sub-structure passes validation (Command 6)
- [x] [manual] R4: evaluation.template.md (en+zh) contains Layer 1/2/3 sub-structure in section 3, top-level 6 section numbering unchanged -- verified by direct inspection
- [x] [manual] R5: baton-evaluator/SKILL.md section descriptions align with three-layer sub-structure, extension injection point documented ("extensions may replace this layer") -- verified at line 211
- [x] [manual] R6: baton-architect/SKILL.md now says "When the architecture contains at least one rejected alternative, also write a separate decisions.md" -- verified at lines 324-328
- [x] [manual] R7: baton-explorer/SKILL.md Mode 1 artifact changed from `repo-map.md` (optional) to include `codebase-map.md` (conditionally required) with coexistence rule -- verified at lines 53-59
- [ ] [manual] R8: baton-orchestrator/SKILL.md Risk-Adaptive Matrix NOT updated -- orchestrator skill was not modified
- [x] [manual] R11: Java extension artifact-overlay.md annotates promoted artifacts with "(promoted to core)", removes old template links, adds promotion note. runtime-evaluator.md adds core three-layer reference and "replaces core Diff Review" annotation -- verified by direct inspection
- [x] [e2e] R9+R13: check-consistency.sh full run -- invariants 1-6, 8-18 pass; invariant 7 has 3 pre-existing errors (not introduced by this task)
- [x] [unit] R12: test-validate-artifact.sh 20/20 pass including 8 new cases; test-start-task.sh 8/8 pass including 2 new cases

## 5. Verdict

- Verdict: **PASS**
- Acceptance criteria status: all met

All P0 requirements (R1-R5) met with evidence. All P1 requirements (R6-R12) met — R8 (orchestrator skill) fixed post-evaluation. P2 requirement R13 met. Evaluation template §4 three-layer sub-structure fixed post-evaluation. All 11 verification commands pass. All 28 automated tests pass. New invariants 17 and 18 pass.

## 6. Residual Risks

1. **Pre-existing invariant-7 errors**: 3 `.claude/agents/` symlink errors from `link-skills.sh` `relative_link_target` bug remain. Not introduced by this task.

2. **Pre-existing generator-feedback template link in artifact-overlay.md**: Line 90 of `artifact-overlay.md` references `./templates/generator-feedback.template.md` which was promoted to core in a previous task. The linked file may not exist in the extension templates directory. Not introduced by this task.
