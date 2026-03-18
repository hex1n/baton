:: 2>nul & @echo off & goto CMDBLOCK
#!/usr/bin/env bash
# run-hook.cmd — polyglot cmd/bash dispatch wrapper
# Adapted from superpowers hooks/run-hook.cmd
# Unix: delegates directly to dispatch.sh
# Windows: searches for Git Bash, then delegates to dispatch.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec bash "${SCRIPT_DIR}/dispatch.sh" "$@"
exit $?

:CMDBLOCK
:: --- Windows path: find Git Bash, then run dispatch.sh ---
:: Key difference from superpowers: calls dispatch.sh (baton's central dispatcher)
:: instead of a single named hook script.
setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"

:: Try standard Git Bash locations (exit immediately on first found)
if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" "%SCRIPT_DIR%dispatch.sh" %* & exit /b !ERRORLEVEL!
)
if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    "C:\Program Files (x86)\Git\bin\bash.exe" "%SCRIPT_DIR%dispatch.sh" %* & exit /b !ERRORLEVEL!
)

:: Fallback: bash on PATH
where bash >nul 2>&1
if !ERRORLEVEL! equ 0 (
    bash "%SCRIPT_DIR%dispatch.sh" %* & exit /b !ERRORLEVEL!
)

:: No bash found — exit silently (hooks are advisory, not blocking)
exit /b 0
