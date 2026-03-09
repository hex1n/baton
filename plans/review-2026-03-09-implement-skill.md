这个 skill 的整体水准是高的，明显比一般“会做事但不控边界”的实现型 skill 更成熟。它抓住了实现阶段最容易失控的三个点：越权改动、计划漂移、验证滞后。
但它也有几个明显问题：触发条件定义不够严谨、规则强度过高导致可执行性下降、文档内存在部分职责重叠和操作歧义。如果直接上线到真实协作流里，我会给 8.3/10。不是因为理念不对，而是因为“治理很强，落地摩擦也很强”。

先说结论

这是一个强约束型 implementation skill，适合高风险代码库、多人协作、要求严格变更控制的场景。
它最有价值的部分不是“教模型怎么写代码”，而是“限制模型什么时候不能写、能写到哪里、偏了以后怎么停”。

但它现在还不够稳，主要有四类问题：
1.	触发层混入了自然语言歧义
比如 "开始"、"实施"、"start building" 这类词太宽，容易误触发。
2.	“只改 plan 中列出的文件”过于刚性
在真实实现里，经常会出现间接修改：类型生成、导出文件、测试夹具、注册表、索引文件、schema、快照。这些不是“意外”，而是正常实现副产物。
3.	把“发现问题就停”推得太绝对
原则上对，但如果小问题也一律停下来等人确认，会让实现流断裂，成本很高。
4.	部分规则重复，且执行粒度不统一
有些写在 Iron Law，有些写在 Self-Check，有些写在 Red Flags，有些又写在 Unexpected Discoveries。原则一致，但操作层有重复和交叉，长期会让 agent 抓不住优先级。

这份 skill 做对了什么

1. 核心控制点是对的

事实：它把实现阶段的边界压在三个锚点上：
•	必须有 BATON:GO
•	只能改 plan 中列出的文件
•	遇到计划外发现先停

这三个锚点形成了一个很强的“实现许可模型”。
这比很多“先写再补计划”的 agent 工作流可靠得多。

判断：这是这个 skill 最大的优点，也是它区别于普通“coding prompt”的地方。它不是在提升生成能力，而是在提升变更治理能力。

2. 把 todo 作为 plan 到 code 的中间层，这个设计是成立的

plan -> todo -> implementation -> verification -> retrospective 这条链路是顺的。
尤其是 todo 里要求：
•	Change
•	Files / write set
•	Verification
•	Dependencies
•	Derived artifacts

这很关键。因为它把“计划文本”转成了“可执行单元”。

推断：如果配合 hook 或 repo automation，这一层甚至可以继续演进成半结构化执行协议，而不只是 markdown 文本。

3. 自检机制比大多数同类设计强很多

它不是只说“改完跑测试”，而是加入了几类很有效的防漂移检查：
•	改后重读代码
•	重读上下文 5+ 行
•	修改同一文件时重新验证历史 todo
•	修 bug 后 grep 旧模式
•	测试断言要检查是不是假阳性

这些都不是空话，是真正能降低 agent 实现阶段错误率的。

判断：这一块质量很高，说明设计者理解 AI coding 的真实失误模式，而不只是写流程口号。

主要问题

1. 触发条件过宽，容易误触发

description 里写的是：
•	plan.md contains BATON:GO
•	user says “implement”, “generate todolist”, “start building”, “实施”, or “开始”

这里最危险的是 "开始"。

事实：在中文协作里，“开始”可能表示：
•	开始研究
•	开始规划
•	开始看一下
•	开始写 todo
•	开始实施

它不是 implementation intent 的充分信号。

风险：误触发实现 skill 后，如果系统真的配了写锁和 hook，模型会以为自己应该进入执行态，导致流程错位。

建议：把触发条件改成“显式进入实施态”的命令，而不是泛化动词。
比如收紧为：
•	implement
•	start implementation
•	generate todolist
•	开始实施
•	开始开发
•	按 plan 执行

不要用单独的“开始”。

置信度：高。因为这是明确的语言触发歧义，不依赖场景猜测。

2. “Only modify files listed in the plan” 太硬，现实中会卡死

这条规则从治理角度是对的，但从工程角度不够细。

问题本质

真实代码改动经常有三类文件：
•	主改动文件：业务代码、测试代码、配置代码
•	派生文件：lockfile、generated types、snapshots、schema artifacts
•	邻接文件：barrel export、registry、route map、feature flag wiring、fixture index

你这个 skill 只对第一类有天然适配，对后两类处理得过于僵硬。

结果

它会让 agent 在大量“正常实现副作用”面前频繁停机。
理论上安全，实际上会拖慢协作，甚至逼着人把 plan 写成过细的文件清单，增加维护负担。

更合理的改法

应该把文件边界分成三层：
1.	Explicit write set：明确允许修改
2.	Pre-authorized derived artifacts：允许自动变更
3.	Adjacent integration files：允许在满足某些条件时修改，并要求记录原因

也就是说，不要只有“允许 / 不允许”二元判断，而要有受控扩展层。

判断：这是当前版本最大的问题之一。不是原则错，而是没有区分“越权改动”和“实现必然外溢”。

3. 对“unexpected discoveries”的分类还不够工程化

它现在分成：
•	Small addition
•	Derived artifact changed
•	Design direction change
•	Stopping mid-implementation

看起来完整，但仍然混了两种维度：
•	变化规模
•	变化性质

真正需要的是按影响范围和是否改变承诺边界来分。

更实用的分法

建议改成四级：

A. Local completion aid
例如补一个私有 helper、小测试夹具。
条件：不改变 public contract，不新增跨模块依赖。
处理：可继续，但必须记录到 todo completion notes。

B. Adjacent integration change
例如新增 export、注册路由、更新 fixture index。
条件：属于完成原计划所必需。
处理：允许继续，但必须追加到 plan/todo 的 write set。

C. Scope extension
例如多修一个相邻 bug、多覆盖一个相关模块。
处理：停止，更新 plan，等待确认。

D. Design change
例如发现方案本身不成立。
处理：停止，退回 planning/annotation cycle。

这样 agent 更容易判断，不会一遇到非原子实现就刹车。

4. “3 failures must stop” 有价值，但定义不清

这条在 Red Flags 和 Action Boundaries 里都提到了，但缺一个关键定义：
什么叫同一种 approach fail 3 次？

是：
•	同一个命令失败 3 次？
•	同一个思路失败 3 次？
•	同一测试失败 3 次？
•	同一个 patch 被 reject 3 次？

没有定义，执行时就会很主观。

建议

明确 failure unit：
•	同一根因导致的重复尝试，算同一种 failure chain
•	只是参数调整、路径修正，不算新 approach
•	明显更换策略，才算新 approach

否则这条会变成“看心情停”。

置信度：高。因为这属于规范可执行性问题，不是风格偏好。

5. “生成 todolist” 与 “实施” 被绑得太死

当前 skill 既负责：
•	进入实施态
•	生成 todo
•	执行 todo
•	收尾 retrospective

这其实已经不是单一 implement skill，而是一个implementation orchestration skill。

问题不在于不能这样做，而在于职责边界会变模糊：
•	如果 todo 已存在但过时，谁负责重排？
•	如果只想补 verification，不想改代码，还进不进 implement？
•	如果用户只说“generate todolist”，这个动作本质上是 planning 的细化，还是 implementation 的开始？

我的判断

这里存在职责重叠，尤其和 baton-plan 容易打架。
更合理的方式是：
•	baton-plan 负责形成可执行计划，可选生成 todo skeleton
•	baton-implement 负责消费 todo 并执行
•	如果要在 implement 中补生成 todo，只能在“plan approved + todo missing”这个狭窄条件下兜底

否则 implement skill 会吞掉 plan skill 的一部分职责。

6. Completion 阶段要求“run full test suite”不够现实

这条理念没问题，但很多项目里 full suite：
•	很慢
•	很脆
•	依赖外部环境
•	在本地不一定可运行

如果把它写成硬要求，agent 只会两种结果：
•	机械执行然后失败
•	假装完成但只跑局部测试

这都不好。

建议改成分层验证
•	必跑：todo 指定验证 + 受影响范围测试
•	条件允许时跑：package/module 级测试
•	若仓库支持且可运行，再跑 full suite
•	如果 full suite 不可运行，必须明确记录原因和未覆盖风险

这样更真实，也更利于审计。

7. 文档有重复，但不是信息增益型重复

这份 skill 有些“强调”其实是在重复同一原则：
•	计划是合同
•	不在 plan 里的不能做
•	漂移就停
•	先验证再勾选

这些原则分别出现在：
•	Iron Law
•	Process
•	Self-Check
•	Red Flags
•	Common Rationalizations
•	Action Boundaries

问题不是重复本身，而是重复没有层级化。
agent 读的时候难以判断：
•	哪些是硬约束
•	哪些是建议
•	哪些是默认行为
•	哪些是异常处理

建议重构文档层级

把内容压成四层：
1.	Hard gates：必须满足，否则不能写代码
2.	Execution protocol：todo 如何执行
3.	Drift detection：自检与复验
4.	Exception handling：发现新情况怎么办

这样比现在更清晰。

一个更关键的问题：它假设 plan 足够完备，这个前提常常不成立

这是这类 skill 的系统性问题，不只是这份文本的问题。

它把 plan 当作实施合同，这没错；
但如果上游 plan 粒度不足、文件范围漏写、验证方法不够具体，那么 implement skill 会陷入两难：
•	严格执行：频繁停机
•	灵活执行：破坏合同

所以这个 skill 的效果，强依赖上游 baton-plan 的质量。

推断：如果 baton-plan 没有强制包含 write set、verification、derived artifacts、dependency graph，这个 implement skill 会变得很痛苦。

判断：单看 implement skill，它是合格的；但放进整套 workflow，必须和 plan skill 联调设计，否则会出现“上游太粗，下游太严”的断层。

我会怎么改

我会保留它的骨架，但做 6 个关键修订。

1. 收紧触发语义

删除 "开始" 这种宽词，只保留明确实施指令。

2. 把文件边界改成三层授权

不是只有“plan 列出文件才允许改”，而是：
•	explicit files
•	expected derived artifacts
•	allowed adjacent integration files

3. 重写 unexpected discoveries 分类

按影响范围和边界变化来分，不按表面类型分。

4. 明确定义 “3 failures”

把 failure chain 的判定标准写清楚。

5. 把 full test suite 改为条件性收尾动作

避免不现实的硬约束。

6. 明确 skill 职责边界

让 “generate todolist” 成为兜底行为，而不是该 skill 的核心入口之一。

综合评价

优势

这是一个治理意识很强的实现 skill。它真正解决的是 AI coding 最危险的问题：
不是“写不出代码”，而是“悄悄写偏、顺手乱改、验证滞后、以为自己没越界”。

局限

它当前版本对现实工程里的“正常外溢修改”容忍度太低，容易把实现流程卡成审批流。
换句话说，它更像“高约束审计型执行器”，还不是“高可用实施执行器”。

适用条件

它最适合：
•	中高风险仓库
•	多人协作
•	需要严格审计
•	代码生成副作用较少
•	团队愿意为 plan 质量投入成本

它不太适合：
•	原型阶段
•	小仓库快速迭代
•	依赖大量生成文件的项目
•	测试基础薄弱、plan 粒度不稳定的团队

评分

我会给：
•	理念与治理能力：9.1/10
•	工程可执行性：7.6/10
•	与上游 planning skill 的协同性：8.0/10
•	整体：8.3/10

推荐结论

推荐保留这份 skill 的核心框架，但不要原样定稿。
最优策略不是推翻重写，而是做一次“工程化去理想化”修订：保留强边界，降低误触发和过度停机。

推荐方案：进入下一版迭代，重点修 6 项：
1.	收紧触发词
2.	放宽并结构化文件授权模型
3.	细化 unexpected discovery 分级
4.	明确 3 failures 的定义
5.	将 full suite 改为条件性要求
6.	和 baton-plan 重划职责边界

原因：这样能保住它最值钱的治理能力，同时明显提升真实仓库里的可执行性。