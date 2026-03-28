param(
    [ValidateSet("install", "update")]
    [string]$Mode = "install",
    [string]$RepoRoot = ".",
    [string]$SourceRoot = "",
    [switch]$DryRun,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$defaultSourceRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = $defaultSourceRoot
}

function New-DirIfNeeded {
    param([string]$Path)

    if ($DryRun) {
        Write-Host "plan  mkdir -p $Path"
        return
    }

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Remove-PathIfExists {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return
    }

    if ($DryRun) {
        Write-Host "plan  rm -rf $Path"
        return
    }

    Remove-Item -Path $Path -Recurse -Force
}

function Copy-FileSafe {
    param(
        [string]$Source,
        [string]$Target
    )

    if ($DryRun) {
        Write-Host "plan  $Target"
        return
    }

    Copy-Item -Path $Source -Destination $Target -Force
    Write-Host "write $Target"
}

function Copy-DirSafe {
    param(
        [string]$Source,
        [string]$Target
    )

    if ($DryRun) {
        Write-Host "plan  $Target"
        return
    }

    Copy-Item -Path $Source -Destination $Target -Recurse -Force
    Write-Host "write $Target"
}

function Append-Unique {
    param(
        [System.Collections.Generic.List[string]]$Items,
        [string]$Value
    )

    if (-not $Items.Contains($Value)) {
        $Items.Add($Value) | Out-Null
    }
}

function Resolve-EffectiveSkillSource {
    param(
        [string]$Name,
        [string]$OverrideSkillsDir,
        [string]$VendorSkillsRoot
    )

    $overridePath = Join-Path $OverrideSkillsDir $Name
    if (Test-Path $overridePath) {
        return $overridePath
    }

    $vendorPath = Join-Path $VendorSkillsRoot $Name
    if (Test-Path $vendorPath) {
        return $vendorPath
    }

    throw "effective skill source not found for $Name"
}

function Link-One {
    param(
        [string]$Source,
        [string]$Target
    )

    if ($DryRun) {
        return "symlink"
    }

    if (Test-Path $Target) {
        Remove-Item -Path $Target -Force
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Target -Target $Source -ErrorAction Stop | Out-Null
        return "symlink"
    } catch { }

    try {
        New-Item -ItemType HardLink -Path $Target -Target $Source -ErrorAction Stop | Out-Null
        return "hardlink"
    } catch { }

    Copy-Item -Path $Source -Destination $Target -Force
    return "copy"
}

function Materialize-RuntimeDir {
    param(
        [string]$TargetDir,
        [System.Collections.Generic.List[string]]$SkillNames,
        [string]$OverrideSkillsDir,
        [string]$VendorSkillsRoot
    )

    New-DirIfNeeded -Path $TargetDir

    foreach ($existing in Get-ChildItem -Path $TargetDir -Filter "harness-*.md" -ErrorAction SilentlyContinue) {
        if ($DryRun) {
            Write-Host "plan  rm -f $($existing.FullName)"
        } else {
            Remove-Item -Path $existing.FullName -Force
        }
    }

    $dirMode = "symlink"
    foreach ($name in $SkillNames) {
        $source = Resolve-EffectiveSkillSource -Name $name -OverrideSkillsDir $OverrideSkillsDir -VendorSkillsRoot $VendorSkillsRoot
        $target = Join-Path $TargetDir $name
        $modeUsed = Link-One -Source $source -Target $target
        if ($modeUsed -eq "copy") {
            $dirMode = "copy"
        } elseif ($modeUsed -eq "hardlink" -and $dirMode -eq "symlink") {
            $dirMode = "hardlink"
        }
        Write-Host "$modeUsed  $target"
    }

    return $dirMode
}

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
$resolvedSourceRoot = (Resolve-Path $SourceRoot).Path

$versionFile = Join-Path $resolvedSourceRoot "spec/VERSION"
if (-not (Test-Path $versionFile)) {
    throw "spec/VERSION not found under source root: $resolvedSourceRoot"
}

$vendorRoot = Join-Path $resolvedRepoRoot ".vendor/baton-harness"
$vendorSpecRoot = Join-Path $vendorRoot "spec"
$vendorSkillsRoot = Join-Path $vendorRoot "skills"
$harnessDir = Join-Path $resolvedRepoRoot ".harness"
$lockfilePath = Join-Path $harnessDir "harness.lock.yaml"
$overrideRoot = Join-Path $harnessDir "overrides"
$overrideSkillsDir = Join-Path $overrideRoot "skills"
$overrideTemplatesDir = Join-Path $overrideRoot "templates"
$overrideTemplatesZhDir = Join-Path $overrideTemplatesDir "zh"

if ($Mode -eq "install" -and (Test-Path $lockfilePath) -and (-not $Force)) {
    throw "Lockfile already exists at $lockfilePath. Run update-harness or pass -Force."
}

if ($Mode -eq "update" -and (-not (Test-Path $lockfilePath))) {
    throw "Lockfile not found at $lockfilePath. Run install-harness first."
}

$version = (Get-Content $versionFile -Raw).Trim()
$upstreamCommit = try {
    (git -C $resolvedSourceRoot rev-parse HEAD 2>$null).Trim()
} catch {
    "unknown"
}
if ([string]::IsNullOrWhiteSpace($upstreamCommit)) {
    $upstreamCommit = "unknown"
}
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"

New-DirIfNeeded -Path (Join-Path $resolvedRepoRoot ".vendor")
New-DirIfNeeded -Path $harnessDir
New-DirIfNeeded -Path $overrideRoot
New-DirIfNeeded -Path $overrideSkillsDir
New-DirIfNeeded -Path $overrideTemplatesDir
New-DirIfNeeded -Path $overrideTemplatesZhDir

Remove-PathIfExists -Path $vendorSpecRoot
Remove-PathIfExists -Path $vendorSkillsRoot
Remove-PathIfExists -Path (Join-Path $vendorRoot "README.md")

New-DirIfNeeded -Path $vendorRoot
Copy-DirSafe -Source (Join-Path $resolvedSourceRoot "spec") -Target $vendorSpecRoot
New-DirIfNeeded -Path $vendorSkillsRoot
Copy-FileSafe -Source (Join-Path $resolvedSourceRoot "README.md") -Target (Join-Path $vendorRoot "README.md")

$vendorSkillFiles = @(Get-ChildItem -Path (Join-Path $resolvedSourceRoot "skills") -Filter "harness-*.md" -File | Sort-Object Name)
if ($vendorSkillFiles.Count -eq 0) {
    throw "No harness skill files found under $resolvedSourceRoot/skills"
}

foreach ($sourceSkill in $vendorSkillFiles) {
    Copy-FileSafe -Source $sourceSkill.FullName -Target (Join-Path $vendorSkillsRoot $sourceSkill.Name)
}

$skillNames = [System.Collections.Generic.List[string]]::new()
foreach ($sourceSkill in $vendorSkillFiles) {
    Append-Unique -Items $skillNames -Value $sourceSkill.Name
}
foreach ($overrideSkill in Get-ChildItem -Path $overrideSkillsDir -Filter "*.md" -File -ErrorAction SilentlyContinue | Sort-Object Name) {
    Append-Unique -Items $skillNames -Value $overrideSkill.Name
}

$runtimeMode = "symlink"
foreach ($runtimeTarget in @(
    (Join-Path $resolvedRepoRoot ".claude/skills"),
    (Join-Path $resolvedRepoRoot ".agents")
)) {
    $dirMode = Materialize-RuntimeDir -TargetDir $runtimeTarget -SkillNames $skillNames -OverrideSkillsDir $overrideSkillsDir -VendorSkillsRoot $vendorSkillsRoot
    if ($dirMode -eq "copy") {
        $runtimeMode = "copy"
    } elseif ($dirMode -eq "hardlink" -and $runtimeMode -eq "symlink") {
        $runtimeMode = "hardlink"
    }
}

if ($DryRun) {
    Write-Host "plan  $lockfilePath"
} else {
    $lockfileContent = @"
schema: harness-lock/v1
upstream:
  name: baton
  version: $version
  commit: $upstreamCommit
install:
  mode: $Mode
  installed_at: $timestamp
layout:
  vendor_root: .vendor/baton-harness
  spec_root: .vendor/baton-harness/spec
  skills_root: .vendor/baton-harness/skills
  runtime_skill_targets:
    - .claude/skills
    - .agents
  runtime_skill_mode: $runtimeMode
  override_roots:
    skills: .harness/overrides/skills
    templates: .harness/overrides/templates
"@
    Set-Content -Path $lockfilePath -Value $lockfileContent
    Write-Host "write $lockfilePath"
}

Write-Host ""
Write-Host "Harness $Mode complete."
Write-Host "Target Repo:   $resolvedRepoRoot"
Write-Host "Source Root:   $resolvedSourceRoot"
Write-Host "Version:       $version"
Write-Host "Commit:        $upstreamCommit"
Write-Host "Runtime Mode:  $runtimeMode"
if ($DryRun) {
    Write-Host "Mode:          dry-run"
}
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Review $lockfilePath"
Write-Host "2. If this was install, run $resolvedRepoRoot/.vendor/baton-harness/spec/bootstrap/init-harness.ps1 -RepoRoot $resolvedRepoRoot"
Write-Host "3. Put local overrides under $overrideRoot"
