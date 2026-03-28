param(
    [string]$RepoRoot = ".",
    [Parameter(Mandatory = $true)][string]$TaskId,
    [string]$Owner = "scoped-explorer",
    [string]$State = "exploring",
    [string]$Notes = "task row created by start-task bootstrap",
    [string]$Language = "",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-NormalizedContent {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    $content = Get-Content -Raw $Path
    $content = $content -replace "`r`n", "`n"
    $content = $content -replace "`r", "`n"
    return $content
}

function Convert-LineToRow {
    param([string]$Line)

    $parts = $Line.Split("|")
    if ($parts.Count -lt 7) {
        return $null
    }

    return [pscustomobject]@{
        Scope = $parts[1].Trim()
        Owner = $parts[2].Trim()
        State = $parts[3].Trim()
        UpdatedAt = $parts[4].Trim()
        Notes = $parts[5].Trim()
    }
}

function Get-ModuleStatusRows {
    param([string]$Path)

    $content = Get-Content -Raw $Path
    $lines = $content -split "`r?`n"
    $rows = @()
    $inTable = $false

    foreach ($line in $lines) {
        if ($line -eq "## State Notes") {
            break
        }

        if ($line -like "| Scope*") {
            $inTable = $true
            continue
        }

        if (-not $inTable) {
            continue
        }

        if ($line -like "|------*") {
            continue
        }

        if ($line.Trim().Length -eq 0 -or (-not $line.Trim().StartsWith("|"))) {
            continue
        }

        $row = Convert-LineToRow -Line $line
        if ($null -eq $row -or $row.Scope -eq "<task-id>") {
            continue
        }

        $rows += $row
    }

    return $rows
}

function Sanitize-Cell {
    param([string]$Value)

    return $Value.Replace("|", "/")
}

function Normalize-LanguageValue {
    param([string]$Value)

    if ($null -eq $Value) {
        return ""
    }

    $normalized = $Value.Trim()
    $commentIndex = $normalized.IndexOf("#")
    if ($commentIndex -ge 0) {
        $normalized = $normalized.Substring(0, $commentIndex).Trim()
    }

    if ($normalized.Length -ge 2) {
        if (($normalized.StartsWith('"') -and $normalized.EndsWith('"')) -or ($normalized.StartsWith("'") -and $normalized.EndsWith("'"))) {
            $normalized = $normalized.Substring(1, $normalized.Length - 2).Trim()
        }
    }

    return $normalized.ToLowerInvariant()
}

function Resolve-LocaleLanguage {
    $candidates = @(
        $env:LC_ALL,
        $env:LC_MESSAGES,
        $env:LANG,
        [System.Globalization.CultureInfo]::CurrentUICulture.Name,
        [System.Globalization.CultureInfo]::CurrentCulture.Name
    )

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        if ($candidate.Trim().ToLowerInvariant().StartsWith("zh")) {
            return "zh"
        }
    }

    return "en"
}

function Resolve-ArtifactLanguage {
    param([string]$LanguagePolicy)

    $policy = Normalize-LanguageValue -Value $LanguagePolicy
    if ([string]::IsNullOrWhiteSpace($policy) -or $policy -eq "auto") {
        return (Resolve-LocaleLanguage)
    }

    return $policy
}

function Get-ProfileArtifactLanguage {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return ""
    }

    foreach ($line in Get-Content $Path) {
        if ($line -match '^\s*artifact_language\s*:\s*(.+?)\s*$') {
            return Normalize-LanguageValue -Value $Matches[1]
        }
    }

    return ""
}

function Get-HumanTemplatePath {
    param(
        [Parameter(Mandatory = $true)][string]$TemplatesDir,
        [Parameter(Mandatory = $true)][string]$TemplateName,
        [Parameter(Mandatory = $true)][string]$ResolvedLanguage
    )

    if (-not [string]::IsNullOrWhiteSpace($script:resolvedRepoRoot)) {
        $overrideRoot = Join-Path $script:resolvedRepoRoot ".harness/overrides/templates"
        $overrideCandidate = if ($ResolvedLanguage -eq "zh") {
            Join-Path (Join-Path $overrideRoot "zh") $TemplateName
        } else {
            Join-Path $overrideRoot $TemplateName
        }

        if (Test-Path $overrideCandidate) {
            return $overrideCandidate
        }
    }

    $candidate = Join-Path $TemplatesDir $TemplateName
    if ($ResolvedLanguage -eq "zh") {
        $candidate = Join-Path (Join-Path $TemplatesDir "zh") $TemplateName
    }

    if (-not (Test-Path $candidate)) {
        throw "Template not found: $candidate"
    }

    return $candidate
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$specRoot = Split-Path -Parent $scriptDir
$templatesDir = Join-Path $specRoot "templates"

$normalizedLanguageOverride = Normalize-LanguageValue -Value $Language
if ((-not [string]::IsNullOrWhiteSpace($normalizedLanguageOverride)) -and ($normalizedLanguageOverride -notin @("auto", "en", "zh"))) {
    throw "Unsupported language: $Language"
}

$ownersFile = Join-Path $specRoot "protocol/owners.txt"
if (-not (Test-Path $ownersFile)) {
    throw "owners.txt not found: $ownersFile"
}
$validOwners = Get-Content $ownersFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
if ($validOwners -notcontains $Owner) {
    throw "Unsupported owner: $Owner"
}

$statesFile = Join-Path $specRoot "protocol/states.txt"
if (-not (Test-Path $statesFile)) {
    throw "states.txt not found: $statesFile"
}
$validStates = Get-Content $statesFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
if ($validStates -notcontains $State) {
    throw "Unsupported state: $State"
}
$script:resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
$resolvedRepoRoot = $script:resolvedRepoRoot
$harnessDir = Join-Path $resolvedRepoRoot ".harness"
$moduleStatusPath = Join-Path $harnessDir "module-status.md"
$historyRoot = Join-Path $harnessDir "history"
$profileLocalPath = Join-Path $harnessDir "profile.local.yaml"

if (-not (Test-Path $harnessDir)) {
    throw "Harness directory not found: $harnessDir. Run init-harness first."
}
if (-not (Test-Path $moduleStatusPath)) {
    throw "Module status file not found: $moduleStatusPath. Run init-harness first."
}

$profileLanguage = Get-ProfileArtifactLanguage -Path $profileLocalPath
if ((-not [string]::IsNullOrWhiteSpace($profileLanguage)) -and ($profileLanguage -notin @("auto", "en", "zh"))) {
    throw "Unsupported artifact language in profile.local.yaml: $profileLanguage"
}

$languagePolicy = if (-not [string]::IsNullOrWhiteSpace($normalizedLanguageOverride)) {
    $normalizedLanguageOverride
} elseif (-not [string]::IsNullOrWhiteSpace($profileLanguage)) {
    $profileLanguage
} else {
    "zh"
}
$resolvedArtifactLanguage = Resolve-ArtifactLanguage -LanguagePolicy $languagePolicy

$existingRows = @(Get-ModuleStatusRows -Path $moduleStatusPath)
$matchingRows = @($existingRows | Where-Object { $_.Scope -eq $TaskId })

if ($matchingRows.Count -gt 0) {
    throw "Task already exists in module-status.md: $TaskId"
}

$openRows = @($existingRows | Where-Object { $_.State -ne "complete" })
if ($openRows.Count -gt 0) {
    $openSummary = ($openRows | ForEach-Object { "$($_.Scope):$($_.State)" }) -join ", "
    throw "Cannot start a new task while non-complete task rows exist: $openSummary"
}

$artifactMap = @(
    @{ Template = "scoped-map.template.md"; Target = "scoped-map.md" }
    @{ Template = "requirements.template.md"; Target = "requirements.md" }
    @{ Template = "architecture.template.md"; Target = "architecture.md" }
    @{ Template = "verification-path.template.md"; Target = "verification-path.md" }
    @{ Template = "retrospective.template.md"; Target = "retrospective.md" }
)

$archivePairs = @()
foreach ($entry in $artifactMap) {
    $targetPath = Join-Path $harnessDir $entry.Target
    $templatePath = Get-HumanTemplatePath -TemplatesDir $templatesDir -TemplateName $entry.Template -ResolvedLanguage $resolvedArtifactLanguage
    $targetContent = Get-NormalizedContent -Path $targetPath
    $templateContent = Get-NormalizedContent -Path $templatePath

    if (($null -ne $targetContent) -and ($targetContent -ne $templateContent)) {
        $archivePairs += @{
            Source = $targetPath
            Name = $entry.Target
        }
    }
}

$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$historyStamp = Get-Date -Format "yyyyMMddTHHmmss"
$previousScope = if ($existingRows.Count -gt 0) { $existingRows[-1].Scope } else { "bootstrap" }
$archiveLabel = (Sanitize-Cell -Value $previousScope).Replace(" ", "-")
$archiveDir = Join-Path $historyRoot "$historyStamp-$archiveLabel"

if ($archivePairs.Count -gt 0) {
    if ($DryRun) {
        Write-Host "plan  $archiveDir"
        foreach ($pair in $archivePairs) {
            Write-Host "plan  $(Join-Path $archiveDir $pair.Name)"
        }
    } else {
        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
        foreach ($pair in $archivePairs) {
            Copy-Item -Path $pair.Source -Destination (Join-Path $archiveDir $pair.Name) -Force
            Write-Host "write $(Join-Path $archiveDir $pair.Name)"
        }
    }
}

foreach ($entry in $artifactMap) {
    $templatePath = Get-HumanTemplatePath -TemplatesDir $templatesDir -TemplateName $entry.Template -ResolvedLanguage $resolvedArtifactLanguage
    $targetPath = Join-Path $harnessDir $entry.Target

    if ($DryRun) {
        Write-Host "plan  $targetPath"
    } else {
        Copy-Item -Path $templatePath -Destination $targetPath -Force
        Write-Host "write $targetPath"
    }
}

$safeTaskId = Sanitize-Cell -Value $TaskId
$safeOwner = Sanitize-Cell -Value $Owner
$safeState = Sanitize-Cell -Value $State
$safeNotes = Sanitize-Cell -Value $Notes

$allRows = @($existingRows)
$allRows += [pscustomobject]@{
    Scope = $safeTaskId
    Owner = $safeOwner
    State = $safeState
    UpdatedAt = $timestamp
    Notes = $safeNotes
}

$moduleStatusContent = @(
    "# Module Status"
    ""
    "| Scope | Owner | State | Updated At | Notes |"
    "|------|------|------|-----------|------|"
)

foreach ($row in $allRows) {
    $moduleStatusContent += "| $($row.Scope) | $($row.Owner) | $($row.State) | $($row.UpdatedAt) | $($row.Notes) |"
}

$moduleStatusContent += @(
    ""
    "## State Notes"
    ""
    "- Current artifacts: active task initialized for $safeTaskId"
    "- Current blockers: none"
    "- Current residual risks: none recorded yet"
    "- Current next decision: run Scoped Explorer"
)

if ($DryRun) {
    Write-Host "plan  $moduleStatusPath"
} else {
    Set-Content -Path $moduleStatusPath -Value ($moduleStatusContent -join [Environment]::NewLine)
    Write-Host "write $moduleStatusPath"
}

Write-Host ""
Write-Host "Harness task initialization complete."
Write-Host "Repo:     $resolvedRepoRoot"
Write-Host "TaskId:   $safeTaskId"
Write-Host "Owner:    $safeOwner"
Write-Host "State:    $safeState"
Write-Host "Language Policy:   $languagePolicy"
Write-Host "Artifact Language: $resolvedArtifactLanguage"
if ($DryRun) {
    Write-Host "Mode:     dry-run"
}
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Fill .harness/scoped-map.md"
Write-Host "2. Update .harness/module-status.md on each state transition"
Write-Host "3. Archive completed task artifacts before the next task start"
