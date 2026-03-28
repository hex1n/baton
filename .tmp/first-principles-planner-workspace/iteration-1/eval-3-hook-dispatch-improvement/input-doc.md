# Hook Dispatch 架构现状分析

## 当前架构

baton 的 hook 系统基于 `dispatch.sh` — 一个纯 bash 脚本，负责将 IDE 事件路由到对应的 hook 脚本。

### 核心组件

1. **dispatch.sh** — 事件调度器
   - 读取 `manifest.conf` 获取事件→脚本映射
   - 解析事件名称，查找对应 handler
   - 执行 handler 脚本并收集输出
   - 处理退出码（0=允许, 2=阻止）

2. **manifest.conf** — 声明式映射表
   ```
   PreToolUse:Write=write-lock.sh
   PreToolUse:Edit=write-lock.sh
   SessionStart=phase-guide.sh
   ```

3. **Hook 脚本** — 各自独立的 .sh 文件
   - write-lock.sh — 在没有 BATON:GO 时阻止文件修改
   - phase-guide.sh — 会话启动时注入上下文
   - prompt-guard.sh — 提示词级别的安全检查

### 执行流程

```
IDE 触发事件 → run-hook.cmd (Windows) / dispatch.sh (Unix)
  → 读取 manifest.conf
  → 匹配事件名
  → 执行对应脚本
  → 返回退出码给 IDE
```

### 已知问题

1. **manifest.conf 是平面结构** — 不支持条件路由（如"只在 plan 阶段启用某 hook"）
2. **Hook 之间无通信机制** — 每个 hook 独立执行，无法共享状态
3. **错误处理粗糙** — 只有退出码，没有结构化错误信息
4. **Windows 兼容性层** — run-hook.cmd 是必要的中间层，增加了复杂度
5. **测试困难** — hook 依赖 IDE 环境变量，单元测试需要大量 mock

### 性能数据

- dispatch.sh 单次执行：~50ms (Unix), ~200ms (Windows/Git Bash)
- manifest.conf 解析：~5ms
- 典型 hook 脚本执行：10-500ms（取决于是否需要文件搜索）

### 使用统计

- 当前 manifest.conf 中有 8 个映射
- 5 个独立的 hook 脚本
- 每次 IDE 工具调用触发 1-2 个 hook
