# Verification Path: positioning-protocol-vs-runtime

**Owner**: `verification-explorer`  
**状态**: `draft`

## 1. 计划检查项

- 文档存在性: `docs/baton-positioning.md` 必须存在。
- 结论检查: 必须明确给出 `protocol-first system with an opinionated/reference runtime`，并说明“现在不应直接做 full runtime product”。
- 三层边界检查: 必须清楚区分 `protocol core`、`reference runtime`、`future runtime product`。
- 灵感边界检查: 必须包含 Anthropic 文章链接，并说明 Baton 借鉴的是 harness 方法，不是直接复刻其内部 runtime 形态。
- 真实工作场景检查: 必须把“需求 → 设计 → review → 实现 → 验证 → 修复 → human close”的闭环需求，明确落到 reference runtime 的职责上。

## 2. 精确命令

```text
bash spec/bootstrap/validate-artifact.sh verification-path .harness/verification-path.md
bash spec/bootstrap/validate-isolation.sh .harness
rg -n "protocol core|reference runtime|runtime product|Anthropic|full runtime product" docs/baton-positioning.md
```

## 3. 前置条件

- 工具链: `bash`、`rg`、仓库内 `spec/bootstrap` 脚本。
- 服务: 无外部服务依赖。
- 夹具 / 测试数据: 无额外夹具；只依赖当前仓库中的 `.harness/` 与 `docs/baton-positioning.md`。
- 环境变量: 无必需环境变量；当前仓库未提供 `.harness/profile.local.yaml`，`validate-isolation.sh` 将采用默认 `strict` 期望。

## 4. Execution Provenance

- Role: verification_explorer
- Isolation mode: strict
- Execution context: isolated_subagent
- Evidence: 冷读 `.harness/requirements.md`、`.harness/architecture.md`、`docs/baton-positioning.md`，并核对文档已包含定位结论、三层边界和 Anthropic 链接；本验证路径使用 `validate-artifact.sh`、`validate-isolation.sh` 与 `rg` 作为可执行检查。
- Fallback policy: 仅在文档 schema 或内容核验失败时返回阻塞；本任务不启用 sequential fallback。
- Fallback reason: none

## 5. Dry-Run 结果

- 命令: `bash spec/bootstrap/validate-artifact.sh verification-path .harness/verification-path.md`
- 结果: 通过。
- 备注: 该命令仅确认 `verification-path.md` 具备必需章节与 provenance 区块。

- 命令: `bash spec/bootstrap/validate-isolation.sh .harness`
- 结果: 通过。
- 备注: 该命令会进一步核验 Role、Isolation mode、Execution context、Evidence 和 Fallback policy。

- 命令: `rg -n "protocol core|reference runtime|runtime product|Anthropic|full runtime product" docs/baton-positioning.md`
- 结果: 通过。
- 备注: 命中文档中的定位结论、三层边界和灵感边界表述。

## 6. 阻塞项

- none

## 7. 回退方案

- 如果主路径失败: 先检查 `docs/baton-positioning.md` 是否仍缺少三层边界或结论句，再修正文档并重跑三条命令。
- 如果测试模块不可用: 本任务不依赖测试模块，保留文档级验证即可。
- 如果仓库当前 build 已损坏: 该任务是纯文档任务，不依赖 build；只要验证命令可运行即可。
