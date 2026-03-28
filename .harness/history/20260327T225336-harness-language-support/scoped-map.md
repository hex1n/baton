# Scoped Map: harness-language-support

**Requirement**: Add Chinese and auto language support for human-facing harness artifacts and make future artifact-writing follow the configured or detected language.
**Domain**: harness templates / bootstrap / role-skill output policy
**Owner**: `scoped-explorer`
**Status**: `complete`

## 1. Scope

- In scope:
  - human-facing `.harness/` artifact templates
  - bootstrap scripts that choose and reset templates
  - role skills that author artifact markdown
  - bootstrap docs / README that explain language selection
- Out of scope:
  - localizing machine-readable control-plane schema such as `module-status.md`
  - translating the full portable spec and adapter docs into multiple languages
  - adding more than the initial `en` / `zh` support set
- Expected write boundary:
  - `spec/templates/*`
  - `spec/bootstrap/*`
  - `skills/harness-*.md`
  - `README.md`, `spec/README.md`, bootstrap docs

## 2. Entry Point

- Primary entry classes or files:
  - `spec/templates/*.template.md`
  - `spec/templates/profile.local.template.yaml`
  - `spec/bootstrap/init-harness.{sh,ps1}`
  - `spec/bootstrap/start-task.{sh,ps1}`
  - `skills/harness-explorer.md`
  - `skills/harness-specifier.md`
  - `skills/harness-architect.md`
  - `skills/harness-verifier.md`
  - `skills/harness-evaluator.md`
  - `skills/harness-retrospective.md`
- Methods, APIs, commands, or scripts:
  - bootstrap scripts copy/reset the artifact templates
  - skills determine how artifact content is written after templates exist
- Why these are the entries:
  - the current English-only behavior comes from both the initial template text and the skill instructions that describe artifact output in English

## 3. Call Chain

```text
user request language / explicit language option
-> bootstrap selects initial artifact templates
-> profile.local.yaml records artifact language policy
-> role skills read language policy or infer from user input
-> scoped-map / requirements / architecture / verification-path / retrospective are written in the selected language
```

## 4. Existing Behavior

- Current observable behavior:
  - all artifact templates in `spec/templates/` are English
  - `init-harness` and `start-task` always copy those English templates
  - role skills describe required sections in English and do not mention language policy
- Current validation rules:
  - `check-consistency.sh` validates owners, states, header alignment, and mirrored skill sync
  - no current check covers template language selection or artifact language policy
- Existing implicit constraints:
  - `module-status.md` is parsed by scripts and should keep a stable control-plane schema
  - Bash and PowerShell bootstrap behavior must stay aligned
  - any auto behavior in shell scripts cannot read chat history directly

## 5. Existing Tests

- Directly relevant tests:
  - `bash spec/bootstrap/start-task.sh --dry-run`
  - `bash spec/bootstrap/check-consistency.sh`
- Nearby reusable tests:
  - `init-harness --dry-run`
  - `sync-skills.sh` after skill changes
- No useful tests found:
  - no direct test suite for localized template selection or skill language instructions

## 6. Dependency / Risk Scan

- Will this likely touch integration or infra?
  - lightly; it changes bootstrap behavior and mirrored skill content
- Will this likely touch migrations or schema?
  - yes, but only in config and template-selection semantics
- Will this likely cross business domains?
  - no; contained to harness usability

## 7. Change Shape

- This looks like:
  - a medium usability / internationalization refinement with template, script, and skill updates
- Estimated file count:
  - roughly 20+ files because each writing skill needs the language policy
- Preferred implementation depth:
  - explicit override plus sane auto fallback, not a full i18n framework

## 8. Open Questions

- Should `auto` for shell bootstrap resolve from environment locale while `auto` for skills resolves from current user request language?
- Should `module-status.md` remain English-only as a control-plane file even when the human-facing artifacts switch to Chinese?

## 9. Recommendation

- Proceed?
  - Yes.
- Suggested next step:
  - Lock the boundary to “localize human-facing artifacts, keep control plane stable,” then implement `--language auto|en|zh` plus skill-level language policy.
