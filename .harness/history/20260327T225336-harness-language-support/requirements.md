# Requirements: harness-language-support

**Topic**: Chinese and auto language support for harness artifacts
**Status**: `complete`
**Sizing**: `Medium`

## 1. Problem

The current harness produces human-facing artifacts from English-only templates and English-only skill guidance. This causes `.harness/scoped-map.md`, `requirements.md`, `architecture.md`, `verification-path.md`, and `retrospective.md` to default to English even when the user is working in Chinese. There is also no documented language policy, so future artifact output cannot reliably follow the user's language.

## 2. Scope

### 2.1 In Scope

- Adding explicit language selection to bootstrap flows (`init-harness`, `start-task`) for human-facing artifact templates.
- Adding a persisted artifact language policy in `.harness/profile.local.yaml`.
- Adding Chinese templates for the human-facing artifacts.
- Updating harness writing skills so artifact output follows explicit language config or auto-detects from the current user request.
- Updating docs to explain the language behavior and its limits.

### 2.2 Out of Scope

- Translating all portable spec / adapter / README content into fully localized copies.
- Localizing the machine-readable control-plane file `task-status.md`.
- Adding more languages than the first supported set (`en`, `zh`).
- Building a general i18n framework or translation pipeline.

## 3. Functional Requirements

### FR-1 Explicit Artifact Language Selection

- `init-harness` and `start-task` must accept a language option with at least `auto`, `en`, and `zh`.
- The selected or configured language must control which human-facing artifact templates are copied into `.harness/`.

### FR-2 Persisted Language Policy

- `.harness/profile.local.yaml` must include an artifact language policy field so later `start-task` resets and writing skills can follow the same default without re-asking.
- An explicit CLI language option must override the persisted default for the current bootstrap operation.

### FR-3 Auto Mode With Clear Precedence

- Language resolution must follow a documented precedence order.
- For bootstrap scripts, `auto` may use environment locale as the fallback because shell scripts cannot see chat history.
- For writing skills, `auto` must follow the primary language of the current user request.

### FR-4 Human-Facing Artifact Localization

- The following artifact templates must support Chinese output:
  - `scoped-map.md`
  - `requirements.md`
  - `architecture.md`
  - `verification-path.md`
  - `retrospective.md`
- The localized templates must preserve the same semantic structure as the English ones.

### FR-5 Stable Control Plane

- `task-status.md` must remain in its existing stable control-plane shape so bootstrap parsing and status transitions do not become language-sensitive.
- The language policy must explicitly document that machine-readable protocol tokens and state names remain canonical English.

### FR-6 Skill-Level Language Compliance

- Artifact-writing harness skills must state how they choose the output language.
- When configured language is `zh`, the artifact should be written in Chinese.
- When configured language is `en`, the artifact should be written in English.
- When configured language is `auto`, the artifact should follow the primary language of the current user request.

## 4. Non-Goals

- Translating `task-status.md` headings or state names.
- Translating every bootstrap console message into Chinese in this first pass.
- Localizing repository-specific profile YAML keys.

## 5. Acceptance Criteria

### AC-1 Bootstrap Supports Language Selection

- [ ] `init-harness.sh` and `init-harness.ps1` accept `language` selection with `auto|en|zh`.
- [ ] `start-task.sh` and `start-task.ps1` accept `language` selection with `auto|en|zh`.
- [ ] If no explicit language is passed, `start-task` can resolve the default from `.harness/profile.local.yaml`.

### AC-2 Chinese Templates Exist

- [ ] Chinese versions exist for the five human-facing artifact templates.
- [ ] Resetting or bootstrapping in `zh` mode yields Chinese headings and placeholder text for those files.

### AC-3 Profile Records The Policy

- [ ] `profile.local.template.yaml` includes an artifact language setting.
- [ ] `init-harness` writes the configured/default language policy into `.harness/profile.local.yaml`.

### AC-4 Skills Follow The Policy

- [ ] All artifact-writing harness skills describe the language-selection rule.
- [ ] The rule explicitly says canonical protocol tokens and state names stay in English when they are machine-readable values.

### AC-5 Docs Explain Auto Behavior

- [ ] Bootstrap docs explain the precedence order for language resolution.
- [ ] The docs distinguish bootstrap auto detection from skill auto detection.
- [ ] The docs explain why `task-status.md` remains stable in English.

## 6. Constraints

- Keep Bash and PowerShell behavior aligned.
- Avoid introducing language-dependent parsing into `task-status.md`.
- Prefer a small explicit mechanism over a generic translation subsystem.
- Preserve existing script behavior when language is left at the default English path.

## 7. Validation Intent

- Dry-run `init-harness` and `start-task` with `--language zh` to verify Chinese template selection.
- Dry-run `init-harness` / `start-task` without explicit language and verify config/default fallback behavior.
- Inspect generated or planned file paths/content to confirm only the human-facing templates localize.
- Grep skill files for the shared artifact language policy wording.
