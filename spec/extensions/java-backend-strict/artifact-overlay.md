# Artifact Overlay

## Goal

Define the additional artifacts required when portable harness v1 is run in
Java backend strict mode.

## Artifact Model

Portable core keeps the minimum set:

- `scoped-map.md`
- `requirements.md`
- `architecture.md`
- `verification-path.md`
- `task-status.md`
- `retrospective.md`

Java backend strict mode extends that set with:

- `codebase-map.md`
- `decisions.md`
- `api-contract.yaml`
- `evaluation-report.md`
- `generator-feedback.md`
- `runtime-signals/`

## Ownership

| Artifact | Writer | Primary Readers | Purpose |
|------|------|------|------|
| `codebase-map.md` | `repo-explorer` | all roles | global repo map for existing systems |
| `decisions.md` | `architect` | `generator`, `reviewer`, `evaluator`, `human` | record Why and Why Not |
| `api-contract.yaml` | `architect` | `generator`, `evaluator` | stable API validation contract |
| `evaluation-report.md` | `evaluator` | `generator`, `human` | findings and go/no-go report |
| `generator-feedback.md` | `generator` | `architect`, `human` | design mismatch escalation |
| `runtime-signals/` | `evaluator` | `evaluator`, `human` | raw runtime evidence |

## Recommended Layout

```text
.harness/
  codebase-map.md
  scoped-map.md
  requirements.md
  architecture.md
  decisions.md
  api-contract.yaml
  verification-path.md
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

In strict mode, treat these as effectively required rather than optional:

- `codebase-map.md`
- `evaluation-report.md`

Portable core leaves some similar artifacts optional. Strict mode does not.

## Communication Rules

1. Agents communicate through files, not chat memory.
2. A role should not edit another role's owned artifact except for explicit archival or bootstrap mechanics.
3. `Generator` must not rewrite `requirements.md` or `decisions.md`.
4. `Evaluator` must not patch source code while writing `evaluation-report.md`.
5. `generator-feedback.md` is the correct place to raise architecture mismatch, not ad hoc source edits.

## Templates

This extension provides starter templates for:

- [codebase-map.template.md](./templates/codebase-map.template.md)
- [decisions.template.md](./templates/decisions.template.md)
- [api-contract.template.yaml](./templates/api-contract.template.yaml)
- [evaluation-report.template.md](./templates/evaluation-report.template.md)
- [generator-feedback.template.md](./templates/generator-feedback.template.md)
- [runtime-signals.README.md](./templates/runtime-signals.README.md)
