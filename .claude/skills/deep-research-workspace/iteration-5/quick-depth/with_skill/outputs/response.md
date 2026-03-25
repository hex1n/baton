dispatch.sh 里没有名为 `hook_dir` 的变量。起"hooks 目录"作用的变量叫 `_dir`，定义在第 8 行：

```bash
_dir="$(cd "$(dirname "$0")" && pwd)"
```

即：取 dispatch.sh 自身路径 (`$0`) 的所在目录，`cd` 进去后用 `pwd` 取得绝对路径。这是 bash 中确定"脚本自身所在目录"的经典惯用法。

`_dir` 在 dispatch.sh 中被用于两处：

1. **定位 manifest.conf**（第 9 行）：`_manifest="$_dir/manifest.conf"` — manifest 和 dispatch.sh 在同一目录。
2. **加载 hook 脚本**（第 52 行）：`( . "$_dir/$_script.sh" )` — manifest 里的 script 字段是相对于 `_dir` 的无后缀名称，加上 `.sh` 后 source 执行。

（以上均 verified: 直接读取 `.baton/hooks/dispatch.sh` 第 8、9、52 行。）

### 调用链上游

dispatch.sh 不是直接被 Claude Code 调用的，中间有一层 `run-hook.cmd`（polyglot 脚本，同时兼容 cmd.exe 和 bash）。调用路径：

```
Claude Code hooks (settings.json)
  → .baton/hooks/run-hook.cmd <event>
    → bash .baton/hooks/dispatch.sh <event>
```

在 run-hook.cmd 中：
- **Windows（cmd.exe 路径）**：用 `%~dp0`（cmd 内置展开，等于脚本自身所在目录）设置 `HOOK_DIR`，然后调用 `"%HOOK_DIR%dispatch.sh"`（第 14-35 行）。
- **Unix（bash 路径）**：用同样的 `$(cd "$(dirname "$0")" && pwd)` 模式得到 `SCRIPT_DIR`，然后 `exec bash "${SCRIPT_DIR}/dispatch.sh"`（第 44-45 行）。

两条路径都保证了传给 dispatch.sh 的 `$0` 是其自身的正确路径，所以 dispatch.sh 第 8 行的 `_dir` 总能正确解析到 `.baton/hooks/` 目录的绝对路径。

（以上 verified: 读取 `.baton/hooks/run-hook.cmd` 第 14、18、44-45 行，以及 `.claude/settings.json` hooks 配置。）
