param()

# Sync canonical skills/ to .claude/skills/ and .agents/.
# Only needed when link-mode is "copy" (symlink/hardlink propagate automatically).

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$batonRoot = (Resolve-Path (Join-Path $scriptDir "..\..")).Path
$skillsDir = Join-Path $batonRoot "skills"
$linkModeFile = Join-Path $skillsDir ".link-mode"

if (-not (Test-Path $linkModeFile)) {
    throw "No .link-mode file found. Run spec/bootstrap/link-skills.ps1 first."
}

$linkMode = (Get-Content $linkModeFile).Trim()

if ($linkMode -ne "copy") {
    Write-Host "link-mode is $linkMode — edits propagate automatically. No sync needed."
    exit 0
}

function Sync-Dir {
    param([string]$TargetDir)

    # Sync flat files: skills/*.md
    $skillFiles = Get-ChildItem -Path $skillsDir -Filter "*.md" -File
    foreach ($sourceFile in $skillFiles) {
        $targetFile = Join-Path $TargetDir $sourceFile.Name
        Copy-Item -Path $sourceFile.FullName -Destination $targetFile -Force
        Write-Host "sync  $targetFile"
    }

    # Sync subdirectory skills: skills/*/SKILL.md
    $subSkills = Get-ChildItem -Path $skillsDir -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName "SKILL.md")
    }
    foreach ($subDir in $subSkills) {
        $targetSubDir = Join-Path $TargetDir $subDir.Name

        # Skip if already a symlink (propagates automatically)
        $item = Get-Item $targetSubDir -ErrorAction SilentlyContinue
        if ($item -and $item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }

        New-Item -ItemType Directory -Path $targetSubDir -Force | Out-Null
        Copy-Item -Path (Join-Path $subDir.FullName "*") -Destination $targetSubDir -Recurse -Force
        Write-Host "sync  $targetSubDir/"
    }
}

Write-Host "==> .claude/skills/"
Sync-Dir -TargetDir (Join-Path $batonRoot ".claude\skills")

Write-Host "==> .agents/"
Sync-Dir -TargetDir (Join-Path $batonRoot ".agents")

Write-Host ""
Write-Host "Sync complete."
