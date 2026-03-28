# Verification Path: harness-language-support

**Owner**: `verification-explorer`
**Status**: `complete`

## 1. Intended Checks

- Build:
  - not applicable; this task changes templates, docs, and bootstrap scripts
- Tests:
  - `init-harness` and `start-task` must resolve and plan localized templates correctly
- Static checks:
  - control-plane files must remain compatible with current invariants
  - skill docs must contain the shared artifact language policy
- Runtime/manual checks:
  - Chinese template selection works in dry-run mode
  - default/no-flag flow still works

## 2. Exact Commands

```text
bash -n spec/bootstrap/init-harness.sh
bash -n spec/bootstrap/start-task.sh
tmp1=$(mktemp -d); touch "$tmp1/package.json"; bash spec/bootstrap/init-harness.sh --repo-root "$tmp1" --profile auto --adapter codex; bash spec/bootstrap/start-task.sh --repo-root "$tmp1" --task-id default-probe
tmp2=$(mktemp -d); touch "$tmp2/package.json"; bash spec/bootstrap/init-harness.sh --repo-root "$tmp2" --profile auto --adapter codex; rm "$tmp2/.harness/profile.local.yaml"; bash spec/bootstrap/start-task.sh --repo-root "$tmp2" --task-id fallback-probe
tmp3=$(mktemp -d); touch "$tmp3/package.json"; LANG=en_US.UTF-8 bash spec/bootstrap/init-harness.sh --repo-root "$tmp3" --profile auto --adapter codex --language auto; LANG=en_US.UTF-8 bash spec/bootstrap/start-task.sh --repo-root "$tmp3" --task-id auto-en
bash spec/bootstrap/sync-skills.sh
bash spec/bootstrap/check-consistency.sh
git diff --check
command -v pwsh
rg -n "artifact_language|Artifact Language Policy|Response Language Policy|--language auto\|en\|zh" README.md spec/README.md spec/bootstrap/init-harness.md spec/bootstrap/start-task.md skills/harness-*.md spec/templates/profile.local.template.yaml spec/templates/zh
```

## 3. Prerequisites

- Toolchain:
  - `bash`
  - standard Unix utilities used by bootstrap scripts
- Services:
  - none
- Fixtures:
  - existing repo with `.harness/` bootstrapped
- Environment variables:
  - locale variables only matter when testing `auto` resolution

## 4. Dry-Run Result

- Command: `bash -n spec/bootstrap/init-harness.sh` and `bash -n spec/bootstrap/start-task.sh`
  - Result: pass
  - Notes: shell syntax is valid after adding language-aware template selection
- Command: temp repo 1 with no language flag, then plain `start-task`
  - Result: pass
  - Notes: default bootstrap now persists `artifact_language: zh`; both `init-harness` and `start-task` generated Chinese human-facing artifacts without any language flag
- Command: temp repo 2 with missing `profile.local.yaml`, then plain `start-task`
  - Result: pass
  - Notes: when no profile policy exists, `start-task` now falls back to Chinese instead of English
- Command: temp repo 3 with `LANG=en_US.UTF-8` and `--language auto`, then plain `start-task`
  - Result: pass
  - Notes: explicit `auto` still works as before; it persisted `artifact_language: auto` and resolved English artifacts from locale
- Command: `bash spec/bootstrap/sync-skills.sh`
  - Result: pass
  - Notes: mirrored `.claude/skills/` and `.agents/` copies were synchronized from canonical `skills/`
- Command: `bash spec/bootstrap/check-consistency.sh`
  - Result: pass
  - Notes: owner/state/header/skill mirror invariants still hold
- Command: `git diff --check`
  - Result: pass
  - Notes: no whitespace or patch formatting issues
- Command: `command -v pwsh`
  - Result: fail
  - Notes: `pwsh` is not installed in the current environment, so PowerShell scripts were aligned by code inspection only and not runtime-verified
- Command: policy grep across docs, skills, and templates
  - Result: pass
  - Notes: language policy, `auto`, and stable-English `module-status.md` guidance are present in the updated surfaces

## 5. Blockers

- none

## 6. Fallbacks

- If the primary path fails:
  - inspect `.harness/profile.local.yaml` and the selected template source to see whether the failure is in policy resolution or template copy
- If the test module is unavailable:
  - not applicable
- If the repo build is already broken:
  - not applicable
