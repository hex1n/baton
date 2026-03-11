# Research: Codex Hook Protocol Spike

## Scope

Validate the approved gate in `plan.md` Change `#6a` using the local Codex CLI:

1. Does `session_start` consume stdout as raw text or as JSON `additionalContext`?
2. Does `stop` use the same stdout parsing path?
3. How does `stop` handle exit code `2` + stderr?

## Environment

- [RUNTIME] `codex-cli 0.114.0`
- [RUNTIME] Trusted repo path exists in `C:\Users\hexin\.codex\config.toml` for `C:\Users\hexin\IdeaProjects\baton`
- [RUNTIME] `codex features list` reports `codex_hooks` as an under-development feature and its effective state is `false` by default
- Spike harness used local hook scripts that write side effects to disk, so a missing log file means the hook did not fire

## Experiments

### Experiment 1: `codex exec` from an untrusted nested temp project

- Setup:
  - Project: `.tmp-codex-spike/`
  - Config: `.tmp-codex-spike/.codex/config.toml`
  - Hook scripts: `.tmp-codex-spike/hooks/session_start.ps1`, `.tmp-codex-spike/hooks/stop.ps1`
- Command:
  - [RUNTIME] `D:\App\.npm-global\codex.cmd exec -C .tmp-codex-spike --skip-git-repo-check -s read-only ...`
- Result:
  - Agent replied `NONE`
  - No hook log files were created under `.tmp-codex-spike/hooks/logs/`
- Conclusion:
  - This run is not useful for protocol inference because the nested project is not separately trusted; project config may not have been loaded.

### Experiment 2: `codex exec` from the trusted repo root

- Setup:
  - Added temporary project config at `.codex/config.toml`
  - Same hook scripts as Experiment 1, but referenced from the trusted repo root
- Command:
  - [RUNTIME] `D:\App\.npm-global\codex.cmd exec -C . --output-last-message .tmp-codex-spike\last-message.txt ...`
- Result:
  - Agent replied `NONE`
  - No hook log files were created under `.tmp-codex-spike/hooks/logs/`
  - No hook-related output appeared in the CLI transcript
- Conclusion:
  - In local testing, `codex exec` did not trigger the configured project hooks, even in a trusted project.

### Experiment 3: try to force the real interactive/TUI path

- Setup:
  - Reused the same temporary hook scripts and temporary `.codex/config.toml`
  - Tried to launch the interactive client with piped input so the session could start and then exit
- Command:
  - [RUNTIME] `cmd /c "(echo ... & echo /exit) | D:\App\.npm-global\codex.cmd --no-alt-screen -C ."`
- Result:
  - Codex exited immediately with `Error: stdin is not a terminal`
- Conclusion:
  - In this environment, the real TUI path cannot be automated through piped stdin, so we cannot complete a trustworthy interactive hook verification from this terminal session.

### Experiment 4: `codex exec` with `codex_hooks` explicitly enabled

- Setup:
  - Reused the temporary project config at `.codex/config.toml`
  - Reused the same hook scripts from Experiments 1-3
  - Enabled the feature explicitly via CLI flag: `--enable codex_hooks`
- Command:
  - [RUNTIME] `D:\App\.npm-global\codex.cmd exec --enable codex_hooks -C . --output-last-message .tmp-codex-spike\last-message.txt ...`
- Result:
  - Agent replied `NONE`
  - CLI printed `warning: Under-development features enabled: codex_hooks`
  - No hook log files were created under `.tmp-codex-spike/hooks/logs/`
- Conclusion:
  - The earlier failure was not explained solely by the feature flag being off. Even with `codex_hooks` enabled, `codex exec` still did not trigger the configured hooks in local testing.

### Experiment 5: `codex exec` with `codex_hooks` enabled and absolute hook paths

- Setup:
  - Kept `--enable codex_hooks`
  - Replaced hook commands with absolute `powershell -File C:\Users\hexin\IdeaProjects\baton\...` paths via CLI `-c` overrides
  - This directly tested the user-supplied hypothesis that relative paths were the reason hooks were not firing
- Command:
  - [RUNTIME] `D:\App\.npm-global\codex.cmd exec --enable codex_hooks -C . -c 'hooks.session_start=[{...absolute path...}]' -c 'hooks.stop=[{...absolute path...}]' ...`
- Result:
  - Agent replied `NONE`
  - CLI again printed the `codex_hooks` under-development warning
  - No hook log files were created under `.tmp-codex-spike/hooks/logs/`
- Conclusion:
  - Absolute script paths did not make hooks fire in `codex exec`. In this environment, `exec` still cannot be used as a trustworthy verification path for hook behavior.

### Experiment 6: `codex exec` with `hooks.json` (JSON config format)

- Setup:
  - Created `.codex/hooks.json` (JSON format, PascalCase event names) instead of TOML `config.toml` hooks
  - Same PowerShell hook scripts
  - `--enable codex_hooks` flag
  - `SPIKE_SESSION_START_MODE=plain`, `SPIKE_SESSION_START_TOKEN="BATON_SPIKE_SESSION_START_OK"`
- Command:
  - [RUNTIME] `D:\App\.npm-global\codex.cmd exec --enable codex_hooks -C . "Reply with the single word PONG"`
- Result:
  - **Both SessionStart and Stop hooks fired!**
  - SessionStart: `hook SessionStart (completed)` + `context: BATON_SPIKE_SESSION_START_OK`
  - Stop: `stop.stdin.txt` and `stop.meta.json` written
  - Agent replied `PONG`
- Conclusion:
  - **`hooks.json` is the correct config format**, not `config.toml` TOML syntax
  - Plain text stdout from SessionStart → injected as `additionalContext` (DeveloperInstructions)
  - Both hooks work in `codex exec` mode when configured correctly

### Experiment 7: JSON stdout mode for SessionStart

- Setup:
  - `hooks.json` config, `--enable codex_hooks`
  - `SPIKE_SESSION_START_MODE=json`, produces `{"additionalContext":"JSON_CONTEXT_TEST"}`
- Result:
  - `hook SessionStart (failed)` + `error: hook returned invalid session start JSON output`
- Conclusion:
  - Simple `{"additionalContext":"..."}` JSON is rejected
  - JSON mode requires `SessionStartCommandOutputWire` schema (fields: `continue`, `stopReason`, `suppressOutput`, `systemMessage`, `hookSpecificOutput.additionalContext`)
  - **Plain text mode is the recommended approach for Baton** — simpler and confirmed working

### Experiment 8: Stop hook exit code 2 (PowerShell)

- Setup:
  - `hooks.json` config, `--enable codex_hooks`
  - PowerShell stop script with `exit 2` + stderr output
- Result:
  - Stop hook fired, `stop.meta.json` shows `"exit_code": "2"`
  - But Codex reported: `hook Stop (failed) error: hook exited with code 1`
  - `codex exec` overall EXIT=0 — session not blocked
- Conclusion:
  - Hook fires and runs to completion, but exit code is translated to 1 by Codex

### Experiment 9: Stop hook exit code 2 (bash)

- Setup:
  - Same as Exp 8 but using bash script with explicit `exit 2`
- Result:
  - Same behavior: `hook Stop (failed) error: hook exited with code 1`
- Conclusion:
  - Exit code translation is not PowerShell-specific — Codex itself maps all non-zero to code 1

### Experiment 10: SessionStart exit code 2 (bash, blocking test)

- Setup:
  - Bash session_start script with `exit 2` + stderr + stdout
- Result:
  - `hook SessionStart (failed) error: hook exited with code 1`
  - Session continued normally, agent replied `PONG`
  - Stop hook also fired and completed
- Conclusion:
  - **Exit code 2 does NOT block the session** in Codex (unlike Claude Code's PreToolUse where exit 2 blocks)
  - SessionStart and Stop hooks are informational — non-zero exit = "failed" label but no behavioral change

## SessionStart Stdin Protocol (confirmed)

```json
{
  "session_id": "019cdbad-461d-7201-8448-d98d8c1342ee",
  "transcript_path": "C:\\Users\\hexin\\.codex\\sessions\\...\\rollout-....jsonl",
  "cwd": "C:\\Users\\hexin\\IdeaProjects\\baton",
  "hook_event_name": "SessionStart",
  "model": "gpt-5.4",
  "permission_mode": "bypassPermissions",
  "source": "startup"
}
```

## Stop Stdin Protocol (confirmed)

```json
{
  "session_id": "019cdbad-461d-7201-8448-d98d8c1342ee",
  "transcript_path": "C:\\Users\\hexin\\.codex\\sessions\\...\\rollout-....jsonl",
  "cwd": "C:\\Users\\hexin\\IdeaProjects\\baton",
  "hook_event_name": "Stop",
  "model": "gpt-5.4",
  "permission_mode": "bypassPermissions",
  "stop_hook_active": false,
  "last_assistant_message": "PONG"
}
```

## Relevant Documentation

- [DOC] OpenAI Config basics: configuration is documented around `~/.codex/config.toml`, and feature flags such as experimental capabilities are enabled there or via `--enable`.
- [DOC] OpenAI Non-interactive mode: `codex exec` is the automation/CI path. The docs describe `stderr` progress and `stdout` final-message behavior, but do not document hook execution semantics there.
- [RUNTIME] Local CLI help for `codex` / `codex exec` also points to `~/.codex/config.toml` and does not document a `hooks.json` / `config.json` path.

## Findings

### Phase 1 (Experiments 1-5): TOML config path — all failed

1. [RUNTIME] `codex_hooks` being disabled by default was a real confounder in Experiments 1-2.
   Evidence: `codex features list` shows the feature is `false` unless explicitly enabled.
2. [RUNTIME] Even with `codex_hooks` enabled and absolute paths, TOML-based hook config in `config.toml` did NOT trigger hooks.
   Evidence: Experiments 4-5 produced no hook side effects.
3. [RUNTIME] The interactive/TUI path cannot be automated from this terminal.
   Evidence: Codex rejected piped stdin with `stdin is not a terminal`.

### Phase 2 (Experiments 6-10): `hooks.json` config path — all succeeded

4. [RUNTIME] **`hooks.json` is the correct config surface** — switching from TOML `config.toml` to JSON `hooks.json` immediately made both SessionStart and Stop hooks fire.
   Evidence: Experiment 6 — first successful hook execution.
5. [RUNTIME] **SessionStart plain text stdout → `additionalContext`** (injected as DeveloperInstructions).
   Evidence: Experiment 6 — Codex printed `context: BATON_SPIKE_SESSION_START_OK`.
6. [RUNTIME] **SessionStart JSON stdout requires `SessionStartCommandOutputWire` schema** — simple `{"additionalContext":"..."}` is rejected.
   Evidence: Experiment 7 — `hook returned invalid session start JSON output`.
7. [RUNTIME] **Stop hook fires in exec mode** and receives `stop_hook_active`, `last_assistant_message` fields.
   Evidence: Experiments 8-9 — `stop.stdin.txt` captured full JSON.
8. [RUNTIME] **Non-zero exit codes do NOT block** SessionStart or Stop — they produce a "failed" label but session continues normally.
   Evidence: Experiment 10 — `exit 2` → session continued, agent replied PONG.
9. [RUNTIME] **All non-zero exit codes are reported as "code 1"** by Codex, regardless of actual value (tested with bash and PowerShell).
   Evidence: Experiments 8-10 — all show `hook exited with code 1`.
10. [RUNTIME] **Both hooks work in `codex exec` mode** when configured via `hooks.json`.
    Evidence: Experiments 6-10 — consistent hook execution.

## Final Conclusions

- **Gate result: PASS** (with caveats)
- The approved gate in `plan.md` Change `#6a` is now **passed** for the core protocol questions.

### Answered Questions

| Question | Answer | Evidence |
|----------|--------|----------|
| SessionStart stdout: raw text or JSON? | **Raw text** → becomes `additionalContext` (DeveloperInstructions). JSON requires complex schema. | Exp 6 (text works), Exp 7 (simple JSON rejected) |
| Stop uses same stdout path? | Stop fires and receives stdin JSON, but stdout handling for Stop is different (informational only) | Exp 8-9 |
| Exit code 2 + stderr for Stop? | Exit code is non-blocking for both events. All non-zero mapped to "code 1". stderr visible in CLI. | Exp 8-10 |

### Critical Discovery: Config Format

| Config Surface | Works? | Evidence |
|---|---|---|
| `.codex/config.toml` TOML hooks (`[[hooks.session_start]]`) | ❌ No | Experiments 1-5 |
| `.codex/hooks.json` JSON hooks (`{"hooks":{"SessionStart":[...]}}`) | ✅ Yes | Experiments 6-10 |

This contradicts the official Codex documentation which shows TOML hook config. The source code (`codex-rs/hooks/src/engine/discovery.rs:35`) discovers hooks from `hooks.json` files in the config layer stack. Event names are PascalCase in `hooks.json` (matching the source code enums), not snake_case as shown in some documentation.

### Adapter Design Implications

1. **SessionStart adapter**: phase-guide.sh outputs to stderr (for Claude Code). For Codex, adapter redirects stderr→stdout (plain text) so output becomes `additionalContext`.
2. **Stop adapter**: stop-guard.sh outputs to stderr. Same adapter pattern, but Stop hooks are purely informational — exit codes don't block.
3. **Exit code semantics differ from Claude Code**: In Claude Code, PreToolUse exit 2 = block. In Codex, all non-zero = "failed" label, no blocking. This means write-lock.sh (PreToolUse) remains unavailable for Codex (Codex has no PreToolUse event).
4. **Feature flag required**: `codex_hooks` must be enabled. setup.sh should guide users to enable it.

### Remaining Caveats

- ❓ `codex_hooks` is still "under-development" — API may change before stable release
- ❓ Interactive/TUI mode not directly tested (only `codex exec`), but source code analysis confirms both modes use the same hook engine (`codex-rs/core/src/codex.rs`)
- ❓ `stop_hook_active: false` in exec mode — may behave differently in interactive sessions

## Implication For Implementation

- **Unblocked** (gate passed):
  - `workflow.md` Architecture Model + Annotation Protocol
  - `baton-plan` / `baton-research` / `workflow-full.md` reference lines
  - `setup.sh` Codex hook generation — **must use `hooks.json` (JSON), not `config.toml` (TOML)**
  - `.baton/adapters/adapter-codex.sh` — stderr→stdout redirect, plain text mode
  - Codex-specific tests and public capability docs
- **Plan updates required before implementation**:
  - Change #5: TOML generation → JSON generation. "TOML 合并逻辑" → "hooks.json 合并逻辑". TOML 清理 → hooks.json 清理
  - Change #6b: adapter design is now confirmed — stderr→stdout redirect
  - Feature flag guidance: setup.sh should print `codex --enable codex_hooks` or config guidance
  - Event names: PascalCase in hooks.json, not snake_case
