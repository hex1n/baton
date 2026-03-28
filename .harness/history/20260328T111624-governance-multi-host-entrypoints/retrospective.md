# Retrospective: governance-multi-host-entrypoints

## 1. 结果

- 关闭状态: `complete`
- 主要阻塞: 无功能性阻塞；唯一残余风险是 PowerShell 路径未运行时验证，因为当前环境没有 `pwsh`
- 人工决策: 确认接受该 PowerShell 运行时验证残余风险，并关闭任务

## 2. 有效做法

- 先把问题定义为“多宿主治理入口缺失”，而不是“再补一份 AGENTS.md”，能避免走向手工双份维护
- 用共享模板 + 物化脚本 + 主一致性检查的组合，比直接复制根文件稳得多
- 把 `init-harness` 一起接上，能保证这个能力不是只在 baton 仓库内部成立，而是对外部分发也成立

## 3. 失败点

- 之前默认认为根目录只有 `CLAUDE.md` 就够了，说明 adapter 层虽然写了 Codex / Cursor 文档，但没有把“宿主真正会读哪个文件”落到 bootstrap 产物
- 当前仍没有在本机完成 PowerShell 运行时验证，说明跨 shell 路径一旦缺少环境，就容易只停留在静态对齐

## 4. 仓库特定经验

- 对 baton 这种同时服务多个 agent host 的仓库，根目录治理入口也应该像 skills 和 templates 一样有单一真源，而不是把某个宿主的文件名当成 canonical
- 根目录 `AGENTS.md` 和 `CLAUDE.md` 都属于协议入口面，不是普通补充文档，值得纳入 `check-consistency.sh` invariant

## 5. Harness 经验

- “adapter 已经写了文档”不等于“协议已经真正落地”；只有当 bootstrap、root entrypoint 和一致性检查都接上，adapter 才算真正可执行
- 这次再次证明，文档 / 协议 / bootstrap 三者必须一起改，否则用户会在真实宿主环境里先遇到空洞

## 6. 可标准化候选

- 后续可以把 root governance template 的宿主映射做成更明确的 metadata，而不只是固定同步到 `CLAUDE.md` / `AGENTS.md`
- 如果未来要更深入支持 Cursor，可以在此基础上再补 `.cursor/rules` 的生成，但应保持 `AGENTS.md` 这条轻量共享入口继续存在
