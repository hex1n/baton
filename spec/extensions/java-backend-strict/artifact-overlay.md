# Artifact Overlay

## Goal

Define the additional artifacts required when portable harness v1 is run in
Java backend strict mode.

## Artifact Model

Portable core keeps the minimum set:

- `exploration.md`
- `requirements.md`
- `architecture.md`
- `verification.md`
- `task-status.md`
- `retrospective.md`

Core also provides these conditionally required artifacts (promoted from
this extension):

- `codebase-map.md` — required when Explorer runs in repo-wide mode
- `decisions.md` — required when architecture contains rejected alternatives
- `generator-feedback.md` — required when generator encounters design mismatch

Java backend strict mode extends the core set with:

- `api-contract.yaml`
- `evaluation-report.md`
- `runtime-signals/`

## Ownership

| Artifact | Writer | Primary Readers | Purpose |
|------|------|------|------|
| `codebase-map.md` | `repo-explorer` | all roles | global repo map for existing systems (**promoted to core**) |
| `decisions.md` | `architect` | `generator`, `reviewer`, `evaluator`, `human` | record Why and Why Not (**promoted to core**) |
| `api-contract.yaml` | `architect` | `generator`, `evaluator` | stable API validation contract |
| `evaluation-report.md` | `evaluator` | `generator`, `human` | findings and go/no-go report |
| `generator-feedback.md` | `generator` | `architect`, `human` | design mismatch escalation |
| `runtime-signals/` | `evaluator` | `evaluator`, `human` | raw runtime evidence |

## Recommended Layout

```text
.harness/
  codebase-map.md
  exploration.md
  requirements.md
  architecture.md
  decisions.md
  api-contract.yaml
  verification.md
  evaluation-report.md
  generator-feedback.md
  task-status.md
  retrospective.md
  runtime-signals/
    sql-log.txt
    performance.json
    transaction-test.md
    actuator-dump.json
```

## Required Promotions From Core

`codebase-map.md` and `decisions.md` are now core conditionally required
artifacts. In strict mode, their trigger conditions are always met:

- `codebase-map.md` — strict mode always runs repo-wide exploration
- `decisions.md` — strict mode always requires explicit decision records

Additionally, treat `evaluation-report.md` as effectively required in
strict mode (extends core `evaluation.md` with runtime signals).

## Communication Rules

1. Agents communicate through files, not chat memory.
2. A role should not edit another role's owned artifact except for explicit archival or bootstrap mechanics.
3. `Generator` must not rewrite `requirements.md` or `decisions.md`.
4. `Evaluator` must not patch source code while writing `evaluation-report.md`.
5. `generator-feedback.md` is the correct place to raise architecture mismatch, not ad hoc source edits.

## Templates

This extension provides starter templates for:

- [api-contract.template.yaml](./templates/api-contract.template.yaml)
- [evaluation-report.template.md](./templates/evaluation-report.template.md)
- [generator-feedback.template.md](./templates/generator-feedback.template.md)
- [runtime-signals.README.md](./templates/runtime-signals.README.md)

Note: `codebase-map.template.md` and `decisions.template.md` have been
promoted to core (`spec/templates/`). The extension no longer maintains
separate copies.
