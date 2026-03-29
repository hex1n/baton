# Architecture: positioning-protocol-vs-runtime

**主题**: 以定位文档形式收敛 Baton 的 protocol / runtime 边界  
**状态**: `approved`  
**规模**: `Small`

## 1. 问题

Baton 的理念来源包含 Anthropic 的 harness 文章，但 Baton 当前仓库同时具备 protocol-first 结构、reference implementation 和逐步增强的 runtime enforcement。缺少一份统一定位文档，会让后续工作在“继续做协议”、“做本地 reference runtime”、“直接做成 runtime product”之间反复摇摆，影响 roadmap 判断。

## 2. 第一性原理拆解

### 2.1 问题陈述

用户真实需要的不是一套抽象文档，而是一个能在实际工作项目里帮助完成需求澄清、方案设计、实现、验证和修复闭环的系统；但系统的长期可迁移价值，又来自 protocol 层的稳定边界而不是单一宿主下的运行时细节。

### 2.2 约束

- README 已公开把 Baton 定位为 portable protocol + reference implementation
- 当前 runtime 能力仍主要服务本地 orchestrated workflow，而不是完整产品级平台
- 文档任务不应在本轮引入新的实现承诺
- 结论要能支撑后续 roadmap，而不只是一次性观点输出

### 2.3 方案类别

- 方案 A: 把 Baton 定位为纯 protocol 项目，reference runtime 只保留为例子
- 方案 B: 把 Baton 定位为 protocol-first system，并明确维护一个 opinionated local reference runtime
- 方案 C: 直接把 Baton 升级为 runtime product，把 protocol 降级成内部实现细节

### 2.4 评估

- 为什么方案 B 胜出:
  - 它保留 Baton 当前最强的可迁移资产：protocol、artifacts、gates、adapter 分层
  - 它又能满足用户在真实工作项目里完成闭环的需要，因为 reference runtime 会提供实际执行面
  - 它与 README 现有公开定位一致，属于澄清和加厚，而不是推翻
- 为什么拒绝方案 A:
  - 纯 protocol 无法满足用户“在实际工作中跑完整闭环”的直接预期
  - 太多关键能力会退回到人工 discipline，而不是系统可用性
- 为什么拒绝方案 C:
  - 当前协议与 adapter 边界仍在收敛期，过早转向 runtime product 会过早绑定宿主能力
  - 工程投入会迅速转向 orchestration、telemetry、job control，而稀释 protocol 核心资产

## 3. 推荐架构

- 方法:
  - 新增一份定位文档，明确推荐 `protocol-first system with an opinionated/reference runtime`
- 关键变更点:
  - 定义三层边界
  - 把 Anthropic 文章的启发与 Baton 的产品边界拆开说清楚
  - 把“真实工作项目闭环”的用户预期转成 reference runtime 的职责集合
  - 给出升级到 runtime product 的触发条件
- 数据 / 控制边界:
  - `spec/` 继续是协议真源
  - `docs/baton-positioning.md` 是产品定位解释层，不是规范层
  - runtime 仍服务 protocol，而不是反过来成为协议定义者
- 向后兼容说明:
  - 不改 README、spec、bootstrap 行为
  - 只是把现有定位解释得更完整

## 4. 影响面扫描

| 文件 | 层级 | 处理方式 | 原因 |
|---|---|---|---|
| `/Users/hex1n/IdeaProjects/baton/docs/baton-positioning.md` | L2 | add | 新增正式定位文档 |
| `/Users/hex1n/IdeaProjects/baton/.harness/scoped-map.md` | L3 | modify | 记录探索结论 |
| `/Users/hex1n/IdeaProjects/baton/.harness/requirements.md` | L3 | modify | 固化需求边界 |
| `/Users/hex1n/IdeaProjects/baton/.harness/architecture.md` | L3 | modify | 固化推荐方案 |
| `/Users/hex1n/IdeaProjects/baton/.harness/verification-path.md` | L3 | modify | 记录文档任务校验路径 |
| `/Users/hex1n/IdeaProjects/baton/.harness/evaluation.md` | L3 | modify | 记录独立评估结果 |

## 5. 验证策略

- 主要检查:
  - 文档文件存在
  - 关键结论和三层边界可直接检索到
  - `.harness/` 工件满足 schema
- 评审重点:
  - 结论是否足够明确
  - 是否与 README 的 protocol-first 定位冲突
  - 是否真正回应“真实工作项目闭环”的使用场景
- 验证无法完全消除的风险:
  - 这是定位判断，不是运行时实证
  - 文档本身不能替代后续 roadmap 验证

## 6. 风险

- 定位写得太抽象，无法指导后续投资
- 定位写得太像 roadmap，提前做出实现承诺
- 若未来 README 不同步，公开表述仍可能分裂

## 7. 自我质疑

1. 这是最优方案类别，还是只是第一个可行方案?
   - 是当前阶段最稳的方案类别，因为它兼顾现有资产与真实使用需求。
2. 还有哪些假设尚未验证?
   - reference runtime 是否会在多个真实项目里稳定复用，仍需要后续项目实证。
3. 一个怀疑者会先质疑什么?
   - “既然最终还是要靠 runtime，为什么不现在就产品化 runtime？” 文档需要直接回答这个问题。
