# Requirements: positioning-protocol-vs-runtime

**主题**: 明确 Baton 的产品定位应以 protocol、reference runtime、future runtime product 三层组织  
**状态**: `approved`  
**规模**: `Small`

## 1. 问题

仓库已经公开把 Baton 定位为 portable AI coding agent collaboration protocol，但用户的真实期待并不是只拥有一套协议文档，而是能在工作项目里稳定完成“需求 → 设计 → review → 实现 → 验证 → 修复 → human close”的闭环。当前缺少一份单独的定位文档，把“为什么核心仍应是 protocol”、“为什么又必须有一个可用的 reference runtime”、“在什么条件下才值得升级成 runtime product”讲清楚，导致后续 roadmap 很容易在抽象协议与重 orchestration 之间摇摆。

## 2. 范围

### 2.1 范围内

- 新增一份正式定位文档，明确回答 Baton 应该做 protocol、runtime product，还是 protocol-first + reference runtime
- 解释 Anthropic 那篇 harness 文章对 Baton 的启发边界
- 结合 Baton 当前仓库状态，说明为什么现在不应直接转向 full runtime product
- 给出适配真实工作项目闭环的推荐演进路线
- 定义未来从 reference runtime 升级到 runtime product 的触发条件

### 2.2 范围外

- 修改 README / README.zh-CN 对外文案
- 修改 spec、adapter、validator、hooks、skills 的实现
- 设计新的状态机、artifact schema 或 telemetry 协议

## 3. 功能需求

### FR-1 定位结论

- 文档必须给出明确结论，不能只列选项
- 结论必须清楚区分 `protocol core`、`reference runtime`、`future runtime product`

### FR-2 启发边界

- 文档必须说明 Anthropic 文章告诉了 Baton 什么
- 文档必须说明 Baton 不应直接复制 Anthropic 内部 runtime 形态的原因

### FR-3 真实工作场景

- 文档必须回应用户的真实使用目标：在工作项目中完成从需求到验证闭环
- 文档必须说明这一目标为什么要求 Baton 不止是文档协议

### FR-4 升级条件

- 文档必须列出什么情况下应该继续保持 protocol-first
- 文档必须列出什么情况下才应该把 Baton 升级成 runtime product

### FR-5 与现有定位一致

- 文档不得与当前 README 中“portable protocol + reference implementation”的公开定位相冲突
- 文档必须把新的判断表述成现有定位的澄清和收敛，而不是推翻

## 4. 非目标

- 不在本任务里给出完整三阶段 roadmap 细项
- 不在本任务里决定 README 是否立刻改版
- 不在本任务里为所有宿主定义统一 telemetry receipt 格式

## 5. 验收标准

### AC-1 文档落地

- `docs/baton-positioning.md` 存在且结构完整

### AC-2 结论明确

- 文档明确推荐 `protocol-first system with an opinionated/reference runtime`
- 文档明确说明“现在不应直接做 full runtime product”

### AC-3 边界清楚

- 文档明确列出三层边界：protocol core、reference runtime、future runtime product

### AC-4 与灵感来源关系清楚

- 文档引用 Anthropic 文章，并说明 Baton 借鉴的是 harness 方法，不是直接复刻其内部运行时

### AC-5 与真实使用目标对齐

- 文档把“真实工作项目闭环”的用户期待转成对 reference runtime 的明确要求

## 6. 约束

- 文档语言使用中文
- 需要与当前仓库已公开定位保持一致
- 只做文档收敛，不引入新的实现承诺

## 7. 验证意图

- 检查 `docs/baton-positioning.md` 是否存在
- 检查文档是否包含 `protocol core`、`reference runtime`、`runtime product` 三层边界
- 检查文档是否包含 Anthropic 文章链接与推荐结论
