# Retrospective: harness-language-support

## 1. 结果

- 关闭状态: `complete`
- 主要阻塞: 无功能性阻塞；唯一残余风险是当前环境缺少 `pwsh`，因此 PowerShell bootstrap 脚本未做运行时验证
- 人工决策: 接受“默认中文”作为本仓库缺省语言，并接受 PowerShell 运行时未验证这一残余风险

## 2. 有效做法

- 将人类可读制品与控制面分开处理是正确的，`module-status.md` 保持英文后，本地化风险明显下降
- 语言策略同时落在模板、bootstrap 脚本、profile 配置和 role skill 上，避免只改一层导致实际执行漂移
- 用临时仓库做 `init-harness` / `start-task` 回归是必要的，这轮顺手抓到了 `start-task.sh` 在空 `rows` 下的 `set -u` 回归

## 3. 失败点

- 第一版把“无配置默认值”设成了英文，直到用户明确要求“默认中文”后才回收敛，说明默认用户画像没有提前固化
- PowerShell 路径仍缺少运行时验证，只能靠脚本对齐和静态审查保证一致性

## 4. 仓库特定经验

- 对 baton 这个仓库，默认中文比 `auto` 更符合真实使用场景，应直接作为 bootstrap 默认值
- 语言相关 skill 说明改动后，必须跑 `spec/bootstrap/sync-skills.sh`，否则 `skills/` 与 `.claude/skills/`、`.agents/` 很容易再次漂移

## 5. Harness 经验

- 语言策略必须有单一优先级规则：显式 CLI override > `profile.local.yaml` > 仓库默认值；`auto` 只作为显式策略存在，不应承担“默认值”角色
- `auto` 的双重语义需要明确写死：脚本看 locale，写制品的 skill 看当前用户输入语言，否则不同阶段会产出不同语言
- 保持控制面英文、叙述性制品本地化，是兼顾可移植性和实际可用性的更稳方案

## 6. 可标准化候选

- 把默认 artifact 语言作为 bootstrap 明文策略，而不是隐含在 README 例子里
- 为 `start-task.sh` 增加“仅模板占位行时也能正常写入”的回归检查，避免空数组在 `set -u` 下再次炸掉
- 继续沿用“环境缺少 `pwsh` 时，必须在 verification-path 和 module-status 里显式记录静态验证残余风险”的做法
