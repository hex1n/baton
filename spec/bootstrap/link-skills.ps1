param([switch]$DryRun)

# Link canonical skills/ to .claude/skills/ and .agents/
# Run from anywhere inside the baton repo — uses script location to find root.
#
# Tier priority (first succeeding tier wins per file):
#   1. SymbolicLink — best for edits; requires developer mode or elevated prompt
#   2. HardLink     — no dev mode needed; same inode so edits propagate
#   3. Copy         — last resort; run sync-skills.ps1 after editing skills/

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$batonRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$skillsDir = Join-Path $batonRoot "skills"
$linkModeFile = Join-Path $skillsDir ".link-mode"

if (-not (Test-Path $skillsDir)) {
    throw "skills/ not found at $skillsDir"
}

function Link-One {
    param(
        [string]$Source,
        [string]$Target
    )

    if ($DryRun) { return "symlink" }

    if (Test-Path $Target) { Remove-Item $Target -Force }

    $relativeTarget = Get-RelativeLinkTarget -Source $Source -Target $Target

    # Tier 1: SymbolicLink
    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $relativeTarget -ErrorAction Stop | Out-Null
        return "symlink"
    } catch { }

    # Tier 2: HardLink
    try {
        New-Item -ItemType HardLink -Path $Target -Target $Source -ErrorAction Stop | Out-Null
        return "hardlink"
    } catch { }

    # Tier 3: Copy
    Copy-Item -Path $Source -Destination $Target -Force
    return "copy"
}

function Get-RelativeLinkTarget {
    param(
        [string]$Source,
        [string]$Target
    )

    $targetDir = Split-Path -Parent $Target
    return [System.IO.Path]::GetRelativePath($targetDir, $Source)
}

function Link-Dir {
    param([string]$TargetDir)

    if ($DryRun) {
        Write-Host "plan  mkdir $TargetDir"
    } else {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    $dirMode = "symlink"
    $skillFiles = Get-ChildItem -Path $skillsDir -Filter "*.md"

    foreach ($sourceFile in $skillFiles) {
        $targetFile = Join-Path $TargetDir $sourceFile.Name
        $mode = Link-One -Source $sourceFile.FullName -Target $targetFile

        if ($mode -eq "copy") { $dirMode = "copy" }
        elseif ($mode -eq "hardlink" -and $dirMode -eq "symlink") { $dirMode = "hardlink" }

        Write-Host "$mode  $targetFile"
    }

    return $dirMode
}

Write-Host "==> .claude/skills/"
$claudeMode = Link-Dir -TargetDir (Join-Path $batonRoot ".claude\skills")

Write-Host "==> .agents/"
$agentsMode = Link-Dir -TargetDir (Join-Path $batonRoot ".agents")

# Overall mode = worst of both
$finalMode = if ($claudeMode -eq "copy" -or $agentsMode -eq "copy") { "copy" }
             elseif ($claudeMode -eq "hardlink" -or $agentsMode -eq "hardlink") { "hardlink" }
             else { "symlink" }

if (-not $DryRun) {
    Set-Content -Path $linkModeFile -Value $finalMode
}

Write-Host ""
Write-Host "link-mode: $finalMode"
if ($finalMode -eq "copy") {
    Write-Host "Run spec/bootstrap/sync-skills.ps1 after editing files in skills/"
}
