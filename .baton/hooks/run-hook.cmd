: << 'CMDBLOCK'
@echo off
REM Cross-platform polyglot wrapper for baton hook dispatcher.
REM On Windows: cmd.exe runs the batch portion, which finds and calls bash.
REM On Unix: the shell interprets this as a script (: is a no-op in bash).
REM
REM Usage: run-hook.cmd <event-name> [args...]

if "%~1"=="" (
    echo run-hook.cmd: missing event name >&2
    exit /b 1
)

set "HOOK_DIR=%~dp0"

REM Try Git for Windows bash in standard locations
if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" "%HOOK_DIR%dispatch.sh" %*
    exit /b %ERRORLEVEL%
)
if exist "C:\Program Files (x86)\Git\bin\bash.exe" (
    "C:\Program Files (x86)\Git\bin\bash.exe" "%HOOK_DIR%dispatch.sh" %*
    exit /b %ERRORLEVEL%
)

REM Modern winget/Windows Store installs Git here
if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" (
    "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" "%HOOK_DIR%dispatch.sh" %*
    exit /b %ERRORLEVEL%
)

REM Portable Git (e.g. D:\App\PortableGit)
if exist "D:\App\PortableGit\usr\bin\bash.exe" (
    "D:\App\PortableGit\usr\bin\bash.exe" "%HOOK_DIR%dispatch.sh" %*
    exit /b %ERRORLEVEL%
)

REM Try bash on PATH
where bash >nul 2>nul
if %ERRORLEVEL% equ 0 (
    bash "%HOOK_DIR%dispatch.sh" %*
    exit /b %ERRORLEVEL%
)

REM No bash found - exit silently (hooks are advisory, not blocking)
exit /b 0
CMDBLOCK

# Unix: delegate to dispatch.sh directly
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec bash "${SCRIPT_DIR}/dispatch.sh" "$@"
