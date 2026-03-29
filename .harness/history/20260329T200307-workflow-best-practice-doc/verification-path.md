# verification-path: workflow-best-practice-doc

## 1. 计划检查项

- 确认 `docs/baton-workflow-best-practice.md` 已存在。
- 确认文档清楚区分 `Core Flow` 与 `Strict Overlay`。
- 确认文档保留 `Verifier`，并把它放在生成前的验证门位置。
- 确认文档中的 `Strict Overlay` 是条件升级，不是 core 默认要求。
- 确认文档与 `docs/baton-positioning.md` 的 `protocol-first + reference runtime` 定位一致，没有把 Baton 写成 `full runtime product`。

## 2. 精确命令

```bash
test -f docs/baton-workflow-best-practice.md && echo OK_DOC_EXISTS
rg -n "Core Flow|Strict Overlay|Verifier|Final Evaluator Pass|blocked|repair loop|protocol-first|reference runtime|full runtime product|strict overlay" docs/baton-workflow-best-practice.md docs/baton-positioning.md
bash spec/bootstrap/validate-artifact.sh verification-path .harness/verification-path.md
bash spec/bootstrap/validate-isolation.sh .harness
```

## 3. 前置条件

- 工作区位于 `/Users/hex1n/IdeaProjects/baton`。
- 仅允许写入 `/Users/hex1n/IdeaProjects/baton/.harness/verification-path.md`。
- 冷读输入已覆盖：
  - `/Users/hex1n/IdeaProjects/baton/.harness/requirements.md`
  - `/Users/hex1n/IdeaProjects/baton/.harness/architecture.md`
  - `/Users/hex1n/IdeaProjects/baton/docs/baton-workflow-best-practice.md`
  - `/Users/hex1n/IdeaProjects/baton/docs/baton-positioning.md`
- 本次判断采用 isolated subagent 视角，不依赖其他 agent 上下文。

## 4. Execution Provenance

- Role: verification_explorer
- Isolation mode: strict
- Execution context: isolated_subagent
- Evidence: `docs/baton-workflow-best-practice.md` 已存在；正文明确出现 `Core Flow`、`Strict Overlay`、`Verifier`、`Final Evaluator Pass`、`blocked`、`repair loop`；并且与 `docs/baton-positioning.md` 的 `protocol-first + reference runtime` 一致。
- Fallback policy: 如果正文缺失或与定位冲突，则回退到补充定位差异说明并标记 blocked。
- Fallback reason: none

## 5. Dry-Run 结果

- `test -f docs/baton-workflow-best-practice.md && echo OK_DOC_EXISTS`：通过，输出 `OK_DOC_EXISTS`
- `rg -n "Core Flow|Strict Overlay|Verifier|Final Evaluator Pass|blocked|repair loop|protocol-first|reference runtime|full runtime product|strict overlay" docs/baton-workflow-best-practice.md docs/baton-positioning.md`：通过
- `bash spec/bootstrap/validate-artifact.sh verification-path .harness/verification-path.md`：通过
- `bash spec/bootstrap/validate-isolation.sh .harness`：通过

结论：文档存在，核心术语齐全，`Strict Overlay` 没有被写成默认 core 要求，且与 `docs/baton-positioning.md` 保持一致。

## 6. 阻塞项

- 无。

## 7. 回退方案

- 如果后续校验发现 `Core Flow` 与 `Strict Overlay` 的边界被改坏，回退到当前这版验证路径，并重新核对正文中关于 `Verifier` 和 `protocol-first + reference runtime` 的表述。
- 如果文档路径变更，先更新验证命令中的目标文件，再重新执行同样的四条命令。
