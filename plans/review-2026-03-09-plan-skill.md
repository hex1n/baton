baton-plan Skill 评审

总评

这份 baton-plan skill 整体质量很高，不是普通的“计划模板”，而是一套带有明显工程治理意识的计划协议。它的核心价值在于：把 plan 从“建议文档”提升为“实现合同”，并通过研究溯源、影响面扫描、自检一致性、批注协议等机制，约束 AI 在实现前的行为边界，降低 scope creep、方向漂移和前后不一致的风险。

但它也存在明显问题：职责过载、流程过重、对执行环境耦合较深、对中小任务不够友好。
问题不是“不专业”，恰恰相反，是它试图把“高质量计划”一次性做到过满，结果把很多原本有价值的治理动作，变成了默认必须承担的流程负担。

综合评分：8.4/10

⸻

核心优点

1. 把 Plan 明确提升为执行契约

这份 skill 最强的地方，是它不是把 plan 当作“建议”或“思路草稿”，而是当作 implementation 的硬前置条件。

像下面这些约束都非常关键：
•	NO IMPLEMENTATION WITHOUT AN APPROVED PLAN
•	NO BATON:GO PLACED BY AI
•	NO INTERNAL CONTRADICTIONS LEFT UNRESOLVED

这类 hard gate 的价值很明确：
它能有效约束 AI 在没有被明确批准前就开始编码，也能减少研究、计划、实现三者之间脱节的问题。

对于多 agent 协作场景，这一点尤其重要，因为多代理最容易失控的地方就是：
•	研究结论和计划脱节
•	计划和实现脱节
•	scope 漂移
•	AI 擅自改变方向

这份 skill 在这些问题上的防护设计是有效的。

判断：应保留，这是该 skill 的核心优势。
置信度：高。

⸻

2. 明确要求 Plan 必须从 Research 推导

Step 1: Derive from Research 的设计是对的，而且质量很高。

它不是泛泛要求“基于研究”，而是明确规定了推导顺序：
1.	优先读取 research.md
2.	若有 ## Final Conclusions，优先以此为单一真源
3.	若没有 Final Conclusions，需要区分当前结论与已被替代的旧结论
4.	人类在 chat 中提供的要求，也必须写进 ## Requirements

这能防止一个常见问题：
AI 前面研究得很认真，后面出计划时却脱离研究内容，回到拍脑袋给方案。

这部分设计说明作者理解“研究结论”和“计划方案”之间应有严格的可追溯关系，而不是语义上 loosely related。

判断：这一部分设计成熟，且非常值得保留。
优势：提高计划的证据链完整性。
局限：如果 research 阶段本身质量不高，就会把错误结论进一步固化。
适用条件：中大型任务、跨模块变更、架构调整。
置信度：高。

⸻

3. Surface Scan 很有价值

Step 3b: Surface Scan 是这份 skill 最有辨识度的设计之一。

它要求在写 change list 前做三层影响面分析：
•	L1：直接引用/直接匹配
•	L2：依赖追踪与调用者追踪
•	L3：行为等价实现的人工辅助识别

最后输出 ## Surface Scan disposition table，并要求：
•	默认 disposition 是 modify
•	skip 必须给出显式理由

这一点非常强，因为它解决的是一个真实工程问题：
很多 plan 表面很完整，实际上只写了主文件修改，外围兼容面、调用者、测试层、同类实现根本没扫。

modify as default 的要求能逼迫 agent 去解释“不改”的依据，而不是因为没想到所以跳过。

判断：这是高级设计，不是形式主义。
优势：显著提升影响面识别能力，降低遗漏风险。
局限：在大型仓库中执行成本高，对 agent 的代码检索和追踪能力要求也高。
适用条件：中大型任务。
置信度：高。

⸻

4. Direction Change Rule 设计成熟

这部分很强，说明作者理解真实协作中“文档一致性”比“局部修补”更重要。

当人工批注导致推荐方案改变时，skill 要求：
1.	明确声明 recommendation 从 X 变成 Y
2.	全文重新对齐
3.	若和 research.md 冲突，先回 research 增补 counter-evidence
4.	提示 human 如需进一步调查可使用 [PAUSE]

这不是普通 prompt 会想到的内容。
它解决的是一个非常实际的问题：人在 review plan 时，一句批注就可能改变方案方向，而多数 agent 只会局部修一句，导致文档前后矛盾。

这套规则本质上是在做方向变更后的全文一致性治理。

判断：建议保留，这是成熟设计。
置信度：高。

⸻

主要问题

1. 职责过载：这已经不只是“plan skill”

这是它最大的问题。

名义上这是 baton-plan，但实际承载的职责包括：
•	从 research 推导方案
•	提炼 requirements
•	提炼 constraints
•	多方案比较
•	Change Impact Analysis
•	Surface Scan
•	测试层覆盖检查
•	Self-Review
•	Annotation Protocol
•	Direction Change Rule
•	Todolist 生成规范
•	计划文件归档规则

也就是说，它已经不只是“计划 skill”，而是把：
•	planning
•	governance
•	review routing
•	impact analysis
•	annotation handling
•	artifact management

全部塞进了一个 skill。

这会带来两个问题：

第一，skill 变得非常重，执行成本高。
第二，任何一个子环节做不好，都会拖累整体输出质量，而且调用者很难判断问题出在哪一层。

事实：这不是单纯 plan，而是前置治理总控。
风险：指令密度过高会降低执行稳定性。
适用条件：强治理、重流程、代码库较复杂的团队。
不适用条件：轻量迭代、快速改动、通用型单代理协作。
置信度：高。

建议
建议拆成至少两层：
•	baton-plan-core：只负责 plan 契约、requirements、constraints、alternatives、recommendation、risks
•	baton-plan-governance：只在中大型任务时增加 Surface Scan、Annotation Protocol、Pre-Exit Checklist、archive policy

这样能显著提高 skill 的可复用性和稳定性。

⸻

2. 对中小任务不够友好，轻重分层不彻底

虽然 skill 中提到：

trivial changes where a 3-5 line plan summary suffices

但整体规则主体仍然是围绕中大型任务设计的。
实际使用中，agent 很容易保守执行，导致中等任务也输出一份过重的 plan。

问题不在于规则本身错，而在于复杂度分层不够显式、不够刚性。

当前版本里虽然提到了 Trivial / Small / Medium / Large，但没有形成清晰的“按级裁剪执行深度”的协议。

结果就是：
skill 逻辑上支持轻量任务，执行上却倾向重型输出。

判断：这是结构问题，不是内容问题。
风险：中小任务 planning 成本过高，降低使用意愿。
置信度：高。

建议
建议直接引入显式复杂度规则，例如：
•	Trivial：3–5 行 summary，无 Surface Scan，无 disposition table
•	Small：requirements + concise recommendation + 简化 change list + L1 scan
•	Medium：+ alternatives + L1/L2 + risk analysis
•	Large：+ L3 + disposition table + full annotation governance + full self-review

只有把裁剪规则写清楚，skill 才不会天然向重型流程倾斜。

⸻

3. “所有前提都必须本轮验证”过于理想化

这一条是典型的“治理目标正确，但执行要求过硬”。

原文要求：

Every assumption the plan depends on … must be directly verified in this session

这在治理上当然理想，但在真实工程里并不总可行。
很多仓库都存在以下情况：
•	某些依赖链难以快速静态确认
•	某些 conventions 并没有文档化
•	某些 runtime 行为无法仅通过代码阅读完全验证
•	某些测试关系是隐式的
•	某些工具链能力不足以在本轮完整确认全部 premise

这里有一个隐含前提需要指出：
“计划质量的提升主要来自把所有前提尽可能验证完。”
这个前提并不成立。

对大多数工程任务，真正决定计划质量的关键是：
•	关键约束识别是否正确
•	主要影响面是否扫描到
•	方案取舍是否清楚
•	不确定性是否被诚实标注

而不是所有 premise 都被验证到位。

判断：这条规则过硬，会导致 agent 卡在查证阶段。
风险：计划产出延迟、执行成本大幅上升。
置信度：高。

建议
建议将 premise 分级：
•	Critical premises：必须验证
•	Non-critical premises：若未验证，必须标记为 assumption
•	Blocked premises：若无法验证，列入风险而非阻塞 plan

这会更符合真实工程场景，也更利于诚实表达不确定性。

⸻

4. “不允许内部矛盾未解决”目标正确，但语义过绝对

这条原则本身没问题。
问题在于 skill 没有清楚区分两种不同的“矛盾”：

第一种：文档内部矛盾
例如：
•	recommendation 选 A
•	change list 实际写的是 B
•	self-review 里又在假定 C

这种必须修，属于真正的文档 bug。

第二种：待人决策的方案分叉
例如：
•	patch 现有结构 vs 根因重构
•	保持向后兼容 vs 允许 breaking change
•	先补测试 vs 先改逻辑
•	局部修复 vs 统一抽象

这类不是“文档写坏了”，而是还存在需要 human judgment 的决策分叉。

当前 skill 虽然后面提到 architecture decision 应交由 human judgment，但整体语气仍然偏向“所有矛盾 presenting 前都要消解”。这会让 agent 倾向于把本应留给人的决策，强行收敛成一个假确定结论。

判断：这里需要语义细化。
风险：agent 过度替 human 决策。
置信度：高。

建议
明确区分：
•	Document contradiction：必须修复
•	Decision fork：可以保留，但必须清楚标注为待人工裁决的分叉点

⸻

5. Todolist 只能在 BATON:GO 后生成，稳，但偏保守

这个设计有明显优点：
•	防止 AI 在 plan 未批准前就开始进入 implementation mindset
•	保证 todo 真正从批准后的 plan 推导出来
•	降低“先做再补 plan”的风险

所以从治理角度看，它是合理的。

但从协作效率看，它又有一个问题：
很多时候 human 想在批准前就一起看“计划是否合理”和“执行拆解是否合理”。

如果 todo 必须严格等到 BATON:GO 之后才能出现，那 human 在批准前看不到真实执行颗粒度，只能看抽象 plan。这会降低 plan 的可审查性。

判断：当前规则更适合强治理场景。
风险：不利于高频快速迭代。
置信度：中高。

建议
建议引入双层产物：
•	Execution Sketch：批准前允许给出非正式任务拆解，仅供审阅，不可执行
•	Todo：批准后正式生成，作为 implementation 依据

这样既不打破 gate，又增强 plan 的可审阅性。

⸻

6. 文件归档规则写死在 skill 中，耦合过深

这条规则：
mkdir -p plans && mv <plan-file> plans/plan-<date>-<topic>.md
本身没错，但它属于 workflow convention，不属于 plan skill 的核心能力。

把它写进主 skill，会隐含假设：
•	项目允许写 plans/
•	所有仓库都接受这种目录结构
•	调用环境有文件写权限
•	使用者认同这种归档策略
•	plan / research 必须以文件形式存在

这些假设并不稳定。

事实：这是 repo/workflow 约定，不是 planning 本质。
风险：skill 对特定仓库组织方式过拟合。
置信度：高。

建议
建议将归档规则下沉到独立的 repo convention 或 artifact policy 中，由 baton-plan 引用，而不是直接内嵌。

⸻

7. Annotation Protocol 很强，但篇幅偏长且重复

Annotation Protocol 这部分设计本身不差，甚至相当成熟。
但它与前面的：
•	Self-Review
•	Direction Change Rule
•	Research conflict handling

之间有明显语义重叠。

问题不是“多写了点”，而是 instruction density 过高。
规则越多，不代表约束越强；很多时候只是让模型更容易抓住格式层，而漏掉真正关键的原则。

判断：应保留核心规则，但需要压缩。
风险：执行时注意力稀释。
置信度：高。

建议
把 Annotation Protocol 压缩成三条核心规则即可：
1.	先读代码和证据，再回应批注
2.	若改变 recommendation，必须声明并全文同步
3.	若与 research 结论冲突，先回 research 补 counter-evidence

其他内容可以放进附录或示例，而不必全部保留在主指令体中。

⸻

内部张力与潜在矛盾

1. 说适用于 any complexity，但主体其实按中大型任务设计

skill 写道：

For tasks of any complexity that involve code changes

这句话表述过宽。
从后文实际规则密度来看，它显然主要是为中大型任务设计的，只是形式上兼容 trivial/small。

更准确的说法应该是：
•	适用于所有涉及代码变更的任务
•	但执行深度必须按复杂度显式裁剪

否则容易误导调用者，以为 trivial task 也应该完整跑整套协议。

⸻

2. 一方面要求不能跳到 how，另一方面又要求尽快形成很具体的 change list

这不是显式冲突，但存在执行张力。

因为 agent 可能还在抽取 constraints、比较 approaches 阶段，就被要求去做：
•	change list
•	surface scan
•	test coverage
•	disposition table

这容易导致两个问题：
•	要么 change list 写得太早，后面 recommendation 一变，整份文档要大改
•	要么 agent 为了避免返工，迟迟不给具体方案

判断：这里缺少更清晰的阶段产物顺序。
置信度：中高。

建议
可以把 plan 生成流程拆得更明确：
1.	Recommendation draft
2.	Aligned change list
3.	Surface Scan / disposition
4.	Self-review / risk / annotation readiness

这样比现在的“步骤有了但产物时序不够明确”更稳。

⸻

最推荐的改进方向

1. 拆分 Core 与 Extended

最值得做的改动不是修几句措辞，而是拆层。

建议：
•	baton-plan-core
•	requirements
•	research derivation
•	constraints
•	alternatives
•	recommendation
•	risk
•	concise self-consistency
•	baton-plan-extended
•	surface scan
•	full disposition table
•	annotation protocol
•	pre-exit checklist
•	archive policy
•	strict todo generation

这样能同时保留治理能力和执行灵活性。

⸻

2. 显式引入复杂度分层

建议把复杂度裁剪写成硬规则，而不是分散在多处：
•	Trivial：summary only
•	Small：summary + recommendation + L1 scan
•	Medium：+ alternatives + L1/L2 + risks
•	Large：+ L3 + disposition table + annotation governance + full self-review

这是把这份 skill 从“强但偏重”变成“强且可落地”的关键。

⸻

3. 把“全部验证”改成“关键前提验证 + 其余显式假设”

建议增加前提分类：
•	Verified fact
•	Working assumption
•	Human decision required

这比要求“所有 premise 都必须验证”更现实，也更能保持输出诚实。

⸻

4. 允许批准前输出 Execution Sketch，批准后输出正式 Todo

这样 human 在批准 plan 前，就能看到执行拆解是否合理；而 BATON:GO 仍然保留为真正的实现门槛。

⸻

5. 压缩主指令体，减少重复治理语句

保留最关键原则即可，不必把相近治理规则在多个 section 重复展开。
这能提高模型执行时的注意力利用率，也有利于长期维护这份 skill。

⸻

最终结论

baton-plan 是一份成熟、严格、治理意识很强的 planning skill。
它最有价值的地方在于：
•	把 plan 变成 implementation contract
•	强调从 research 反推方案
•	用 Surface Scan 和一致性检查降低遗漏
•	对批注后的方向变化有完整治理逻辑

但它当前最大的问题不是“不够严格”，而是过度把高质量 planning 和重型治理流程绑定在一起。
这导致它：
•	对中小任务不够友好
•	对 agent 执行能力要求偏高
•	对具体仓库流程有一定过拟合
•	在通用协作环境中可能偏重

综合评价：高质量，但偏重。
最终评分：8.4/10。

最推荐的优化路径：
1.	拆分 core / extended
2.	明确复杂度分层
3.	将“全验证”改为“关键前提验证 + 显式假设”
4.	区分 document contradiction 与 decision fork
5.	允许批准前提供 execution sketch

⸻

一句话版总结

baton-plan 不是普通计划模板，而是一套“计划即合同”的强治理 skill。优点是边界清晰、可追溯、抗漂移；缺点是职责过载、流程过重、分层不够彻底。适合中大型工程任务，不够适合所有复杂度任务默认直接全量执行。综合评分 8.4/10。