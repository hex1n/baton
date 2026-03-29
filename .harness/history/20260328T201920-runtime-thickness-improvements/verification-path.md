# Verification Path: runtime-thickness-improvements

**Owner**: `verification-explorer`
**状态**: `verified (rev3)`

## 1. 计划检查项

| AC | 检查方式 |
|----|---------|
| AC-1：Explorer frontmatter + 模式说明 + dispatch note | grep 文件内容 |
| AC-2：Evaluator CC Execution Note | grep |
| AC-3：Verifier CC Execution Note | grep |
| AC-4：claude-code.md Context Isolation 节 | grep |
| AC-5：.claude/agents/ 三个 symlinks | ls -la |
| AC-6：check-consistency.sh 全部通过（含不变式 7） | 运行脚本 |
| AC-7：P1-2 补注 | grep |

## 2. 精确命令

```bash
# AC-1
grep -n "context: fork" skills/baton-explorer.md
grep -n "Repo-wide mode\|Claude Code" skills/baton-explorer.md | head -10

# AC-2
grep -n "Claude Code Execution Note" skills/baton-evaluator.md

# AC-3
grep -n "Claude Code Execution Note" skills/baton-verifier.md

# AC-4
grep -n "Context Isolation\|Agent tool\|baton-evaluator" spec/adapters/claude-code.md | head -10

# AC-5
ls -la .claude/agents/

# AC-6
bash spec/bootstrap/check-consistency.sh

# AC-7
grep -c "实现状态" docs/harness-improvement-plan.md
```

## 3. 前置条件

- bash、grep、ln（均已可用）
- `.claude/` 目录已存在

## 4. Dry-Run 结果（实现前已验证可执行）

- AC-1 命令：可执行，grep 无语法错误 ✅
- AC-6：`bash spec/bootstrap/check-consistency.sh` 当前 exit 0 ✅（实现后须含不变式 7）
- 其余命令：grep 类，可执行 ✅

## 5. 阻塞项

none

## 6. 回退方案

- AC-6 不变式 7 失败：检查 `.claude/agents/` symlink 是否正确；检查 check-consistency.sh 不变式 7 逻辑
- AC-5 symlink 不存在：重新运行 `ln -s` 命令
