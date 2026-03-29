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

function Link-SubDir {
    # Link a skill subdirectory (containing SKILL.md) as a directory symlink/copy.
    # Claude Code discovers skills by scanning for <dir>/SKILL.md.
    param(
        [string]$SourceDir,
        [string]$TargetDir
    )

    if ($DryRun) { return "symlink" }

    # Clean up stale flat-file link from previous runs
    $staleFlatFile = Join-Path (Split-Path -Parent $TargetDir) ("$(Split-Path -Leaf $TargetDir).md")
    if (Test-Path $staleFlatFile) { Remove-Item $staleFlatFile -Force }

    if (Test-Path $TargetDir) { Remove-Item $TargetDir -Recurse -Force }

    $relTarget = Get-RelativeLinkTarget -Source (Join-Path $SourceDir "SKILL.md") -Target (Join-Path $TargetDir "SKILL.md")
    $relDir = Split-Path -Parent $relTarget

    # Tier 1: SymbolicLink (directory)
    try {
        New-Item -ItemType SymbolicLink -Path $TargetDir -Target $relDir -ErrorAction Stop | Out-Null
        return "symlink"
    } catch { }

    # Tier 2: Copy directory (no hardlink for directories)
    try {
        Copy-Item -Path $SourceDir -Destination $TargetDir -Recurse -Force
        return "copy"
    } catch { }

    Write-Warning "Could not link or copy $SourceDir"
    return "error"
}

function Link-Dir {
    param([string]$TargetDir)

    if ($DryRun) {
        Write-Host "plan  mkdir $TargetDir"
    } else {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    $dirMode = "symlink"

    # Flat files: skills/*.md
    $skillFiles = Get-ChildItem -Path $skillsDir -Filter "*.md"

    foreach ($sourceFile in $skillFiles) {
        $targetFile = Join-Path $TargetDir $sourceFile.Name
        $mode = Link-One -Source $sourceFile.FullName -Target $targetFile

        if ($mode -eq "copy") { $dirMode = "copy" }
        elseif ($mode -eq "hardlink" -and $dirMode -eq "symlink") { $dirMode = "hardlink" }

        Write-Host "$mode  $targetFile"
    }

    # Subdirectory skills: skills/*/SKILL.md → target_dir/<name>/
    $subSkills = Get-ChildItem -Path $skillsDir -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName "SKILL.md")
    }

    foreach ($subDir in $subSkills) {
        $targetSubDir = Join-Path $TargetDir $subDir.Name
        $mode = Link-SubDir -SourceDir $subDir.FullName -TargetDir $targetSubDir

        if ($mode -eq "copy") { $dirMode = "copy" }

        Write-Host "$mode  $targetSubDir/"
    }

    return $dirMode
}

function Link-ForkDir {
    # Link only skills with `context: fork` into target directory.
    param([string]$TargetDir)

    if ($DryRun) {
        Write-Host "plan  mkdir $TargetDir"
    } else {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    $dirMode = "symlink"

    # Flat fork skills: skills/*.md with context: fork
    $skillFiles = Get-ChildItem -Path $skillsDir -Filter "*.md"
    foreach ($sourceFile in $skillFiles) {
        if (-not (Select-String -Path $sourceFile.FullName -Pattern "^context: fork" -Quiet)) { continue }
        $targetFile = Join-Path $TargetDir $sourceFile.Name
        $mode = Link-One -Source $sourceFile.FullName -Target $targetFile

        if ($mode -eq "copy") { $dirMode = "copy" }
        elseif ($mode -eq "hardlink" -and $dirMode -eq "symlink") { $dirMode = "hardlink" }

        Write-Host "$mode  $targetFile"
    }

    # Subdirectory fork skills: skills/*/SKILL.md with context: fork
    $subSkills = Get-ChildItem -Path $skillsDir -Directory | Where-Object {
        $skillFile = Join-Path $_.FullName "SKILL.md"
        (Test-Path $skillFile) -and (Select-String -Path $skillFile -Pattern "^context: fork" -Quiet)
    }
    foreach ($subDir in $subSkills) {
        $targetSubDir = Join-Path $TargetDir $subDir.Name
        $mode = Link-SubDir -SourceDir $subDir.FullName -TargetDir $targetSubDir

        if ($mode -eq "copy") { $dirMode = "copy" }

        Write-Host "$mode  $targetSubDir/"
    }

    return $dirMode
}

Write-Host "==> .claude/skills/"
$claudeMode = Link-Dir -TargetDir (Join-Path $batonRoot ".claude\skills")

Write-Host "==> .agents/"
$agentsMode = Link-Dir -TargetDir (Join-Path $batonRoot ".agents")

Write-Host "==> .claude/agents/ (context:fork only)"
$claudeAgentsMode = Link-ForkDir -TargetDir (Join-Path $batonRoot ".claude\agents")

# Overall mode = worst of all directories
$finalMode = if ($claudeMode -eq "copy" -or $agentsMode -eq "copy" -or $claudeAgentsMode -eq "copy") { "copy" }
             elseif ($claudeMode -eq "hardlink" -or $agentsMode -eq "hardlink" -or $claudeAgentsMode -eq "hardlink") { "hardlink" }
             else { "symlink" }

if (-not $DryRun) {
    Set-Content -Path $linkModeFile -Value $finalMode
}

Write-Host ""
Write-Host "link-mode: $finalMode"
if ($finalMode -eq "copy") {
    Write-Host "Run spec/bootstrap/sync-skills.ps1 after editing files in skills/"
}
