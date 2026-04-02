# Task Status

| Scope | Owner | State | Eval Round | Updated At | Notes |
|------|------|------|-----------|-----------|------|
| add-version-flag | — | complete | 0 | 2026-03-26T18:35:00+0800 | human confirmed close, retrospective recorded |
| protocol-consistency-fix | — | complete | 0 | 2026-03-27T21:20:00+0800 | human confirmed close; all 6 AC criteria met; retrospective recorded |
| harness-workflow-improvements | — | complete | 0 | 2026-03-27T21:41:00+0800 | human accepted PowerShell runtime residual risk; retrospective recorded |
| harness-language-support | — | complete | 0 | 2026-03-27T22:14:21+0800 | human confirmed close; default language set to Chinese; retrospective recorded; PowerShell runtime residual risk accepted |
| harness-distribution-installer | — | complete | 0 | 2026-03-27T23:14:12+0800 | human confirmed close; install/update/lockfile/override workflow accepted; retrospective recorded; PowerShell runtime residual risk accepted |
| root-readme-bilingual | — | complete | 0 | 2026-03-27T23:20:19+0800 | human confirmed close; bilingual root README accepted; retrospective recorded |
| root-readme-standardization | — | complete | 0 | 2026-03-27T23:38:00+0800 | human confirmed close; root README bilingual checks and governance rules accepted; retrospective recorded |
| governance-multi-host-entrypoints | — | complete | 0 | 2026-03-27T23:56:00+0800 | human confirmed close; shared governance template, AGENTS.md root entrypoint, bootstrap sync, and consistency checks accepted; retrospective recorded |
| runtime-thickness-improvements | — | complete | 0 | 2026-03-28T13:20:00+0800 | human confirmed close; cross-platform isolation implemented; all 7 AC criteria met; retrospective recorded |
| isolation-enforcement-hardening | — | complete | 0 | 2026-03-28T22:24:00+0800 | human accepted residual risks; strict/compat isolation semantics hardened; isolated verifier and evaluator artifacts written; focused tests, consistency check, and live isolation validators passed; retrospective recorded |
| provenance-standardization-hardening | — | complete | 0 | 2026-03-28T22:58:00+0800 | human accepted result with no additional residual risk; shared provenance contract implemented; shared reader added; human-close surface now shows verifier/evaluator provenance and verdict; focused tests and live validators passed; retrospective recorded |
| positioning-protocol-vs-runtime | — | complete | 0 | 2026-03-28T23:21:00+0800 | human accepted the positioning result; docs/baton-positioning.md now defines Baton as protocol-first with a local reference runtime, not an immediate full runtime product; retrospective recorded |
| workflow-best-practice-doc | — | complete | 0 | 2026-03-28T22:23:00+0800 | human accepted the workflow best-practice result; docs/baton-workflow-best-practice.md now defines default core flow plus conditional strict overlay and aligns with baton-positioning; retrospective recorded |
| runtime-enforcement-hardening | — | complete | 1 | 2026-03-29T23:24:00+0800 | human confirmed close; isolated verification/evaluation passed; retrospective recorded; advisory human_ack residual risk accepted |
| bootstrap-structure-rationalization | — | complete | 0 | 2026-03-29T22:56:52+0800 | human confirmed close; best-practice guardrails implemented; strict isolated verifier/evaluator passed with Agent IDs; retrospective recorded; Windows live smoke-test residual risk accepted |

## State Notes

- Current artifacts: scoped-map.md, requirements.md, architecture.md, verification-path.md, evaluation.md, retrospective.md
- Current blockers: none
- Current residual risks: no live Windows host smoke test for `run-hook.cmd`; current evidence is command-generation and shell-test coverage
- Current next decision: none
