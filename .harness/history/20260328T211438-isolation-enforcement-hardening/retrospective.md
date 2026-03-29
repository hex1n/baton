# Retrospective: isolation-enforcement-hardening

## 1. 结果

- 关闭状态: `complete`
- 主要阻塞: 无长期阻塞；中途暴露的是协议要求与 runtime enforcement 之间的缺口
- 人工决策: human 接受残余风险，并确认本任务可以关闭

## 2. 有效做法

- 先把问题缩成“strict / compat 语义、artifact provenance、stop-time validation”三个最小闭环，而不是直接上重 orchestrator。
- 用真正隔离的 verifier / evaluator subagent 重跑关键角色，避免这次改完协议却继续用非合规执行方式验证自己。
- 把 `evaluation.md` 从 optional 提升到 human close 前的显式工件，明显提高了 gate 4 的可执行性。

## 3. 失败点

- 最初实现虽然补了模板和 validator，但 live `.harness/verification-path.md` 仍然因为中文 section 标题近义词和反引号值解析问题被 validator 拦下，说明 schema 收紧后 live artifact 对齐不能省。
- `install-hooks.sh` 写当前仓库 `.codex/hooks.json` 仍会遇到本地权限限制，导致 hook 安装在真实工作区和临时测试目录里的表现不完全一致。

## 4. 仓库特定经验

- Baton 现在真正缺的不是更多流程概念，而是让“隔离是否真的发生”成为 control plane 与 gate 的一部分。
- 一旦支持中英文 artifact，validator 不能只识别英文 section 名，否则语言支持和 runtime enforcement 会互相打架。
- `start-task` 重置列表只要漏一个正式工件，就会把前一任务的事实源残留到下一任务。

## 5. Harness 经验

- “Context isolation responsibility belongs to orchestrator” 这条原则必须继续保留，但 Baton 不能只停在原则层，必须把降级模式和证据显式化。
- `strict` 与 `compat` 必须是协议字段，不是适配器里的模糊注释。
- human close 之前除了 state 以外，还要能一眼看见 verifier / evaluator 的 provenance 和 verdict。

## 6. 可标准化候选

- 给所有需要独立判断的 artifact 统一保留 provenance 段，字段名固定，避免每次再发明一套写法。
- 把“模板更新 -> validator 更新 -> start-task reset 列表更新 -> tests 覆盖”固化成同一批次变更规则。
- 后续如果接平台 telemetry，再把当前 artifact-level provenance 升级为“artifact 证据 + runtime 证据”双重校验。
