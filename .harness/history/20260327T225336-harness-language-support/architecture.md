# Architecture: harness-language-support

**Topic**: Chinese and auto language support for harness artifacts
**Status**: `approved`
**Sizing**: `Medium`

## 1. Problem

The harness has no artifact language model today. Templates are English-only, bootstrap scripts always copy English versions, and artifact-writing skills never explain how to follow the user's language. As a result, Chinese-speaking users still get English `.harness` artifacts by default.

## 2. First-Principles

### 2.1 Problem Statement

The solution should make human-facing artifact output language-aware without destabilizing the machine-readable control plane. The harness does not need a full translation framework; it needs a small, explicit policy that both scripts and skills can follow.

### 2.2 Constraints

- Do not make `task-status.md` parsing language-sensitive.
- Keep Bash and PowerShell bootstrap behavior aligned.
- Support an explicit language override and a default automatic mode.
- Avoid adding external dependencies for language detection.

### 2.3 Solution Categories

- Category A: translate every template and every control-plane file, including `task-status.md`.
- Category B: localize only the human-facing artifacts, keep `task-status.md` stable, and add a small persisted language policy plus bootstrap/skill rules.
- Category C: leave templates English-only and only tell skills to “write Chinese when needed”.

### 2.4 Evaluation

- Why Category B wins:
  - It fixes the actual user-visible problem while preserving script stability.
  - It gives bootstrap and skills a shared policy instead of relying on model memory.
  - It keeps the implementation small and deterministic.
- Why Category A is rejected:
  - It would force the control plane and parsing logic to become language-aware, which adds fragility for limited user value.
- Why Category C is rejected:
  - The blank templates would still start in English, and script-driven resets would keep reintroducing English headings.

## 3. Recommended Architecture

- Approach:
  - Keep the current English templates as the stable default set.
  - Add Chinese versions of the five human-facing artifact templates under a dedicated localized template directory.
  - Add `--language auto|en|zh` to `init-harness` and `start-task`.
  - Store the artifact language policy in `profile.local.yaml`.
  - Resolve `auto` differently by execution layer:
    - bootstrap scripts: environment locale fallback
    - harness writing skills: current user request language
  - Keep `task-status.md` and canonical protocol tokens in English.
- Confirmed decisions:
  - D1: only human-facing artifacts localize in this pass
  - D2: `task-status.md` remains stable English control plane
  - D3: `auto` means locale-based fallback in shell/PowerShell, user-input-based fallback in skill execution
  - D4: CLI override takes precedence over profile-local default
- Key change points:
  - localized templates under `spec/templates/zh/`
  - `spec/templates/profile.local.template.yaml`
  - `spec/bootstrap/init-harness.{sh,ps1,md}`
  - `spec/bootstrap/start-task.{sh,ps1,md}`
  - artifact-writing skills in `skills/harness-*.md`
  - top-level docs in `README.md` and `spec/README.md`
- Data/control boundaries:
  - human-facing artifacts: localized
  - control-plane files and canonical token sources: stable English
  - profile-local config: stores the preferred artifact language policy
- Backward-compatibility notes:
  - existing repos without `documentation.artifact_language` should continue to function
  - the flat English templates remain valid and are still the default resolved output when language resolves to `en`

## 4. Surface Scan

| File | Level | Disposition | Reason |
|---|---|---|---|
| `spec/templates/profile.local.template.yaml` | L1 | modify | persist artifact language policy |
| `spec/templates/scoped-map.template.md` | L1 | keep | English default template remains canonical default |
| `spec/templates/requirements.template.md` | L1 | keep | English default template remains canonical default |
| `spec/templates/architecture.template.md` | L1 | keep | English default template remains canonical default |
| `spec/templates/verification-path.template.md` | L1 | keep | English default template remains canonical default |
| `spec/templates/retrospective.template.md` | L1 | keep | English default template remains canonical default |
| `spec/templates/zh/*` | L1 | add | Chinese human-facing templates |
| `spec/bootstrap/init-harness.sh` | L1 | modify | add language option and localized template selection |
| `spec/bootstrap/init-harness.ps1` | L1 | modify | add language option and localized template selection |
| `spec/bootstrap/start-task.sh` | L1 | modify | add language option, profile fallback, and localized template selection |
| `spec/bootstrap/start-task.ps1` | L1 | modify | add language option, profile fallback, and localized template selection |
| `skills/harness-explorer.md` | L1 | modify | add artifact language policy for `scoped-map.md` |
| `skills/harness-specifier.md` | L1 | modify | add artifact language policy for `requirements.md` |
| `skills/harness-architect.md` | L1 | modify | add artifact language policy for `architecture.md` |
| `skills/harness-verifier.md` | L1 | modify | add artifact language policy for `verification-path.md` |
| `skills/harness-generator.md` | L2 | modify | cover optional `generator-feedback.md` and execution notes |
| `skills/harness-evaluator.md` | L1 | modify | add artifact language policy for findings/evaluation output |
| `skills/harness-retrospective.md` | L1 | modify | add artifact language policy for `retrospective.md` |
| `skills/harness-status.md` | L2 | optional modify | align user-facing status language with artifact language policy |
| `README.md` / `spec/README.md` / bootstrap docs | L2 | modify | explain language options and auto semantics |

## 5. Validation Strategy

- Primary checks:
  - `bash spec/bootstrap/init-harness.sh --repo-root . --profile auto --adapter codex --task-id lang-probe --language zh --dry-run`
  - `bash spec/bootstrap/start-task.sh --repo-root . --task-id lang-probe --language zh --dry-run`
  - `bash spec/bootstrap/start-task.sh --repo-root . --task-id lang-probe --dry-run`
  - `bash spec/bootstrap/check-consistency.sh`
  - `rg -n "artifact_language|language policy|auto|zh" spec/bootstrap skills README.md spec/README.md`
- Review focus:
  - only human-facing artifacts localize
  - `profile.local.yaml` records the policy
  - skills explain the same precedence order
- Risks that validation cannot fully eliminate:
  - `pwsh` may still be unavailable locally
  - skill compliance remains instruction-based rather than machine-enforced

## 6. Risks

- `auto` semantics differ by layer; if the docs are unclear, users may assume shell bootstrap can read chat language.
- If future contributors localize `task-status.md` casually, bootstrap parsing will break.
- Chinese templates and English templates can drift structurally if they are edited independently without discipline.

## 7. Self-Challenge

1. Is this the best category, or only the first workable one?
   - Best for now. It fixes user-facing output without destabilizing the control plane.
2. Which assumptions remain unverified?
   - That locale-based `auto` is an acceptable fallback for bootstrap usage.
3. What would a skeptic challenge first?
   - Whether keeping `task-status.md` in English is surprising. The answer is yes, but the script-stability tradeoff is worth making explicit.
