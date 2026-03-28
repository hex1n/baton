param(
    [string]$RepoRoot = ".",
    [string]$SourceRoot = "",
    [switch]$DryRun,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$installScript = Join-Path $scriptDir "install-harness.ps1"

& $installScript -Mode update -RepoRoot $RepoRoot -SourceRoot $SourceRoot -DryRun:$DryRun -Force:$Force
