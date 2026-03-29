@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "HOOK_NAME=%~1"

if "%HOOK_NAME%"=="" (
  echo ERROR: missing hook name 1>&2
  exit /b 1
)

set "HOOK_PATH=%SCRIPT_DIR%%HOOK_NAME%"

set "BASH_EXE="
for %%P in (
  "%ProgramFiles%\Git\bin\bash.exe"
  "%ProgramFiles(x86)%\Git\bin\bash.exe"
  "%LocalAppData%\Programs\Git\bin\bash.exe"
) do (
  if exist %%~P (
    set "BASH_EXE=%%~P"
    goto run_hook
  )
)

for /f "delims=" %%I in ('where bash 2^>NUL') do (
  set "BASH_EXE=%%I"
  goto run_hook
)

echo ERROR: Git Bash not found. Install Git for Windows and ensure bash.exe is available. 1>&2
exit /b 1

:run_hook
shift
"%BASH_EXE%" "%HOOK_PATH%" %*
exit /b %ERRORLEVEL%
