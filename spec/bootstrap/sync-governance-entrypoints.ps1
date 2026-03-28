param(
    [string]$RepoRoot = ".",
    [ValidateSet("sync", "check")]
    [string]$Mode = "sync",
    [switch]$Force,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$specRoot = Split-Path -Parent $scriptDir
$templatePath = Join-Path $specRoot "templates/root-governance.template.md"
$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
$targets = @(
    (Join-Path $resolvedRepoRoot "CLAUDE.md"),
    (Join-Path $resolvedRepoRoot "AGENTS.md")
)

if (-not (Test-Path $templatePath)) {
    throw "Template not found: $templatePath"
}

$expected = Get-Content $templatePath -Raw
$errors = 0

foreach ($target in $targets) {
    $label = Split-Path $target -Leaf

    if ($Mode -eq "check") {
        if (-not (Test-Path $target)) {
            Write-Host "ERROR: governance entrypoint missing: $target"
            $errors += 1
            continue
        }

        $actual = Get-Content $target -Raw
        if ($actual -eq $expected) {
            Write-Host "OK: governance entrypoint synced: $label"
        } else {
            Write-Host "ERROR: governance entrypoint drifted from template: $label"
            $errors += 1
        }
        continue
    }

    if ((Test-Path $target) -and ((Get-Content $target -Raw) -eq $expected)) {
        Write-Host "skip  $target"
        continue
    }

    if ((Test-Path $target) -and (-not $Force.IsPresent)) {
        Write-Host "skip  $target (differs; pass --force to overwrite)"
        continue
    }

    if ($DryRun) {
        Write-Host "plan  $target"
        continue
    }

    Set-Content -Path $target -Value $expected
    Write-Host "write $target"
}

if ($Mode -eq "check") {
    if ($errors -eq 0) {
        Write-Host "governance entrypoints OK"
        return
    }

    throw "$errors error(s) found"
}

Write-Host "governance entrypoint sync complete"
