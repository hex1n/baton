# Architecture: root-readme-standardization

**主题**: 根目录 README 双语维护标准化
**状态**: `approved`
**规模**: `Small`

## 1. 问题

根目录 README 双语布局已经建立，但仍缺两类稳定机制：一类是自动发现双语入口漂移的仓库自检；另一类是把维护规则写回治理文档，让后续 README 入口改动默认按 harness 闭环执行，而不是退回纯人工约定。

## 2. 第一性原理拆解

### 2.1 问题陈述

这里不是“有没有 README.zh-CN.md”的问题，而是“仓库如何持续证明双语入口仍然存在、仍然覆盖相同的接入面、且维护者知道什么时候必须同时更新两份 README”。如果这三个点缺任意一个，现状仍然会随着后续修改再次漂移。

### 2.2 约束

- 不能把根目录 README 重新合并成单文件中英混排
- 不希望引入复杂文档平台或生成流程
- 仓库已有 `check-consistency.sh`，应优先复用
- 规则最好写在现有治理入口，减少新增载体

### 2.3 方案类别

- 方案 A: 只写治理规则，不做自动检查
- 方案 B: 只补脚本，不写治理规则
- 方案 C: 独立自检脚本 + 整合进现有自检 + 治理规则回写

### 2.4 评估

- 为什么方案 C 胜出:
  - 既能自动发现 drift，也能把“何时需要双语同步、何时要走 harness”写成规则
  - 复用现有 `check-consistency.sh`，摩擦最小
  - 维护成本显著低于引入完整文档流水线
- 为什么拒绝方案 A:
  - 仍然高度依赖人记住规则，无法提前暴露 drift
- 为什么拒绝方案 B:
  - 脚本能发现错，但不能告诉维护者哪些改动本来就应该同步双语、也无法把 harness 经验沉淀回治理

## 3. 推荐架构

- 方法:
  - 新增专用脚本 `spec/bootstrap/check-root-readme-bilingual.sh`
  - 在 `check-consistency.sh` 中增加一个新的 invariant 调用该脚本
  - 在 `CLAUDE.md` 中新增“文档贡献 / README 入口规则”段落
  - 在两份根目录 README 顶部补一行轻量维护提示，提升可见性
- 关键变更点:
  - README 双语自检从“临时手工核对”升级为“脚本 + 主自检入口”
  - 根目录入口文档任务被正式纳入 harness 约束
- 数据 / 控制边界:
  - 检查对象仅限根目录 `README.md` 和 `README.zh-CN.md`
  - 不把该规则扩展到所有 docs
- 向后兼容说明:
  - 不改变现有 README 结构，只增加规则与校验

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 | 原因 |
|---|---|---|---|
| `.harness/scoped-map.md` | L1 | modify | 记录本任务探索结果 |
| `.harness/requirements.md` | L1 | modify | 固化需求 |
| `.harness/architecture.md` | L1 | modify | 固化方案 |
| `.harness/verification-path.md` | L1 | modify | 记录验证路径 |
| `.harness/module-status.md` | L1 | modify | 跟踪当前任务状态 |
| `spec/bootstrap/check-root-readme-bilingual.sh` | L1 | add | 新增 README 双语自检 |
| `spec/bootstrap/check-consistency.sh` | L1 | modify | 把 README 检查接入主自检 |
| `CLAUDE.md` | L1 | modify | 写回治理规则 |
| `README.md` | L1 | modify | 增加维护提示 |
| `README.zh-CN.md` | L1 | modify | 增加维护提示 |

## 5. 验证策略

- 主要检查:
  - README 双语自检脚本可运行且通过
  - 主一致性检查会覆盖新脚本
  - diff 无格式错误
- 评审重点:
  - 章节 / 关键术语选择是否足够代表根目录入口文档
  - 治理规则是否足够清晰而不过度扩张
- 验证无法完全消除的风险:
  - 脚本只能校验结构与关键术语，不能自动判断两份 README 的全部语义是否完全同步

## 6. 风险

- 关键章节名单如果未来变动，脚本也需要一起更新
- README 维护提示与治理规则可能再次漂移，需要通过同一改动同步

## 7. 自我质疑

1. 这是最优方案类别，还是只是第一个可行方案?
   - 对当前仓库规模是最优的轻量方案；更重的文档系统不值得
2. 还有哪些假设尚未验证?
   - 尚未验证 PowerShell 是否也需要对应 README 检查脚本；当前需求仅覆盖 bash 自检即可
3. 一个怀疑者会先质疑什么?
   - “为什么不直接只靠人工维护？” 回答是这次改动本来就是为了解决人工维护漂移
