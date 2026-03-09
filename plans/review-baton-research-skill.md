我先给结论：这个 skill 的研究方法论很强，但它目前更像一份“研究阶段宪法”，而不是一个触发边界清晰、约束自洽、可稳定自动调用的 Claude skill。我的评分是 7.8/10：研究框架 9/10，技能工程化 6.5/10。置信度：高。依据是我直接审阅了该 SKILL.md，并对照了 Claude Code 官方关于 skills、subagents、hooks 的文档；但我没有同时检查它依赖的 workflow.md 和 write-lock hook 配置，所以对“配套系统是否已补足这些问题”这一点仍有不确定性。

核心判断

这个 skill 的真实目标很明确：把“研究”和“实现”硬拆开，要求先做证据化理解，再进入计划或编码；并通过 call chain、consistency matrix、counterexample sweep、self-review、Final Conclusions、Questions for Human Judgment 这些机制，降低拍脑袋分析和错误规划的概率。这个方向本身是对的，而且比大多数随手写的 skills 强很多。

但它有一个根本问题：方法论强，不等于 skill 设计好。
现在这份文件把“研究纪律”写得很完整，却没有把“何时触发、如何局部约束、如何在不同环境里稳定执行”设计清楚。结果就是：内容上很强，工程上不够稳。

做得好的部分

第一，反模式打击得很准。它明确禁止“看接口就下结论”“顺手修一下”“凭印象总结”，并要求所有主要结论都经历反例搜索。这不是空话，这确实能显著减少代码理解阶段的幻觉和草率判断。

第二，Consistency Matrix 很有价值。很多跨 IDE、跨 endpoint、跨配置格式的问题，单纯追主调用链是会漏的；矩阵要求每个格子都要有直接证据、N/A、运行验证或明确的未验证原因，这比“我大概都看了”强太多。

第三，Final Conclusions + superseded conclusions 这一套设计是成熟的。它知道长研究文档最大的问题不是“信息少”，而是“旧结论没死透”。要求显式标记被后文推翻的旧结论，并在末尾收敛成单一真相源，这一点非常好。

第四，它确实在逼模型把“事实、未知、需要人判断的部分”分开。这比很多一上来就给方案的 skill 更可靠。

主要问题
1）触发条件过宽，而且自相矛盾

事实：它在 description 里写了“用户一旦说 research / analyze / investigate / explore / understand how this works，或者只要碰到不熟悉代码，即使任务看起来简单，也必须用这个 skill”；同时在正文又说 Small/Trivial 且范围清晰时不该用。官方文档明确说明，description 就是 Claude 判断何时调用 skill 的核心依据；如果 skill 触发过于频繁，应该把 description 写得更具体，或者直接用 disable-model-invocation: true 改成手动触发。

推断：这份 description 很容易过触发。因为“analyze / understand / unfamiliar code”几乎覆盖了大量正常开发对话。
判断：这是当前最大缺陷。它会把一个本该用于“深研究”的 skill，变成“几乎所有非平凡任务都先进入 research phase”的总入口，成本高、延迟高、还会挤占正常实现路径。

2）它宣称“研究期禁止改代码”，但约束没有被 skill 自身编码

事实：这份 skill 的 frontmatter 只有 name、description、user-invocable: true，没有使用官方支持的 allowed-tools、context: fork、agent 等能力。官方文档明确支持用 allowed-tools 限制技能可用工具，也支持 context: fork + agent: Explore 把 skill 放进只读 subagent 中；而 Explore 本身就是为代码搜索和只读分析设计的。该 skill 反而把“禁止写代码”主要寄托在外部 write-lock hook 上。

推断：这导致它自包含性差、可移植性差。离开配套 hook，这个“不改代码”的承诺就主要变成了提示词自律。
判断：如果这是一个要共享、复用、跨环境运行的 skill，这种设计不够硬。正确做法应该是：能放在 frontmatter 里硬限制的，就别只写在正文里求自觉。

3）“Every claim requires file:line evidence. No exceptions.” 写得太绝对，且和它自己后面的要求冲突

事实：它一边要求“所有 claim 都必须有 file:line 证据，没有例外”，一边又要求在遇到外部依赖边界时查权威文档，还要求把“Human requirement (chat)”写入 Final Conclusions。前者不是仓库 file:line，后者更不是代码证据。

推断：这说明它的证据模型没有分层。
判断：这里应该改成证据类型分级，而不是一句“全都必须 file:line”。更合理的是至少分成四类：
[CODE] file:line、[DOC] 外部权威文档、[RUNTIME] 命令/实验输出、[HUMAN] 用户明确要求。
否则严格执行时会自撞，宽松执行时又会破坏规则权威性。

4）Step 0 的 Tool Inventory 有点仪式化过头

事实：它要求在任何代码调查前先盘点所有可用检索工具，并尝试每个相关工具，再记录各自返回了什么。

判断：这个思路出发点没错——防止只用一种搜索手段造成盲区——但写法太像流程 KPI。问题不在“鼓励多工具交叉验证”，而在“先盘点一遍全部工具”这件事本身会制造大量无效动作。对很多任务来说，Grep + Read 就足够；强行把 Context7、WebSearch、WebFetch、MCP servers 都列上，会把 skill 从“高质量研究”推向“形式主义研究”。

更好的写法应该是：至少使用两种互补检索方式，但只要求记录“为什么这些方式足够覆盖当前问题”，而不是要求先做工具普查。

5）它在“用 subagent”这件事上写在正文里了，但没落实到配置层

事实：正文要求在 3+ call paths、10+ files 时使用 subagents；官方文档则直接支持 skills 通过 context: fork 运行在隔离上下文里，并支持指定 agent: Explore。

推断：现在这份 skill 的 subagent 使用是“倡议”，不是“机制”。
判断：如果你真的相信 research phase 适合只读、隔离、并行，那就不该只在正文说“记得这么做”，而应该在 frontmatter 里部分固化。

6）有几个小但真实的工程瑕疵

事实：research-.md 看起来明显像笔误；user-invocable: true 在 Claude Code 里本来就是默认值；3+ annotations signal depth issues 这种硬阈值也比较武断。

判断：这些不是大问题，但会暴露出它还没完全收口。一个高质量 skill，应该尽量减少这种“作者自己懂，但配置层没打磨干净”的痕迹。

我给的结论：保留什么，重写什么

最该保留的，是这四块：

Counterexample Sweep

Consistency Matrix

Final Conclusions / superseded conclusions

Questions for Human Judgment

这四块是它真正有辨识度的价值。

最该重写的，是这三块：

description / trigger 条件

只读约束的实现方式

证据标准的分层模型

推荐修改方案
方案 A：把它做成“手动深研 skill”

适用条件：你希望 research phase 很重、很严格，不想让 Claude 自己乱触发。
做法：加 disable-model-invocation: true，把它变成显式 /baton-research。官方文档就是这么建议处理高成本、需要人工控制时机的 skill。优势是边界清晰、不会误触发；风险是自动化降低，需要操作者有流程意识。

方案 B：保留自动触发，但把 description 收窄

适用条件：你就是想让 Baton workflow 自动介入。
做法：description 改成只覆盖这些场景：
“跨多个模块的行为追踪、复杂/中大型任务、需求或行为存在歧义、用户明确要求 deep research。”
不要再写“只要 unfamiliar code—even if simple”。
优势是还能自动触发；风险是仍然可能有误判，但会比现在好很多。官方文档也明确说，skill 过度触发时优先把 description 写得更具体。

方案 C：把只读约束真正落到配置

适用条件：你希望“研究期不改代码”不是口号。
做法：优先考虑 context: fork + agent: Explore，因为官方文档已经把 Explore 定义成只读分析代理；如果不走 fork，也至少加 allowed-tools 做硬限制。优势是约束可执行、可迁移；风险是灵活性下降，某些临时 runtime 验证动作需要额外白名单。

方案 D：把证据标准改成分层

适用条件：你想让规则长期可执行，不自相矛盾。
做法：把
“No conclusions without file:line evidence”
改成
“No code-behavior conclusions without direct evidence. Prefer repo file:line; otherwise label evidence type explicitly.”
优势是规则更严谨；风险是文档稍长，但这是值得的。

我会怎么改

我不会整份推翻。我会做“保骨架、换外壳”的重构。

建议最小改法如下：

---
name: baton-research
description: Produce an evidence-backed research note before planning or implementation for medium/large, ambiguous, or cross-cutting code investigations.
context: fork
agent: Explore
# 如果你不想自动触发，就再加：
# disable-model-invocation: true
---

然后把正文里这句：

Every claim requires file:line evidence. No exceptions.

改成：

Evidence must be explicit.
- [CODE] repo file:line for code behavior claims
- [DOC] authoritative external docs for dependency/framework behavior
- [RUNTIME] command output for observed runtime behavior
- [HUMAN] chat-stated requirements or constraints

Do not present code-behavior conclusions without direct evidence.

再把 Step 0 改成“至少两种互补检索方式”，而不是“先盘点所有工具”。

最终推荐

我的推荐不是“废掉这个 skill”，而是：

保留它的研究方法论，重构它的 skill 工程化边界。

原因很简单：
它的思想是对的，甚至比大多数团队里的分析流程更成熟；但它现在把“研究纪律”写得太满，把“触发精度”和“可执行约束”做得太轻。这样会导致两个后果：一是误触发，二是离开配套 hook 后约束失效。
