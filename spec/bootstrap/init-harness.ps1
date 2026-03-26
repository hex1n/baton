param(
    [string]$RepoRoot = ".",
    [ValidateSet("auto", "java-maven", "node-monorepo", "python-service")]
    [string]$Profile = "auto",
    [ValidateSet("codex", "claude-code", "cursor")]
    [string]$Adapter = "codex",
    [switch]$Force,
    [switch]$DryRun,
    [switch]$DetectOnly,
    [string]$TaskId = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Copy-IfNeeded {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][bool]$Overwrite
    )

    if ((Test-Path $Target) -and (-not $Overwrite)) {
        Write-Host "skip  $Target"
        return
    }

    if ($DryRun) {
        Write-Host "plan  $Target"
        return
    }

    Copy-Item -Path $Source -Destination $Target -Force
    Write-Host "write $Target"
}

function Resolve-Profile {
    param(
        [Parameter(Mandatory = $true)][string]$RepoPath,
        [Parameter(Mandatory = $true)][string]$RequestedProfile
    )

    if ($RequestedProfile -ne "auto") {
        return $RequestedProfile
    }

    if (Test-Path (Join-Path $RepoPath "pom.xml")) {
        return "java-maven"
    }

    if ((Test-Path (Join-Path $RepoPath "pnpm-workspace.yaml")) `
            -or (Test-Path (Join-Path $RepoPath "turbo.json")) `
            -or (Test-Path (Join-Path $RepoPath "nx.json")) `
            -or (Test-Path (Join-Path $RepoPath "package.json"))) {
        return "node-monorepo"
    }

    if ((Test-Path (Join-Path $RepoPath "pyproject.toml")) `
            -or (Test-Path (Join-Path $RepoPath "requirements.txt")) `
            -or (Test-Path (Join-Path $RepoPath "pytest.ini"))) {
        return "python-service"
    }

    throw "Unable to auto-detect profile for repo: $RepoPath"
}

function Get-DefaultCommands {
    param([Parameter(Mandatory = $true)][string]$SelectedProfile)

    switch ($SelectedProfile) {
        "java-maven" {
            return @{
                Build = "mvn -pl <module> -am -DskipTests compile"
                Test = "mvn -pl <module> -am test"
                OptionalStaticCheck = "mvn -pl <module> -am -DskipTests compile"
                HighRisk = @("integration", "bootstrap", "migrations")
            }
        }
        "node-monorepo" {
            return @{
                Build = "pnpm --filter <package> build"
                Test = "pnpm --filter <package> test"
                OptionalStaticCheck = "pnpm --filter <package> lint"
                HighRisk = @("shared-packages", "infra", "codegen")
            }
        }
        "python-service" {
            return @{
                Build = "python -m compileall <package>"
                Test = "pytest <path>"
                OptionalStaticCheck = "python -m compileall <package>"
                HighRisk = @("migrations", "settings", "jobs")
            }
        }
        default {
            throw "Unsupported profile: $SelectedProfile"
        }
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$specRoot = Split-Path -Parent $scriptDir
$templatesDir = Join-Path $specRoot "templates"
$profilesDir = Join-Path $specRoot "profiles"
$adaptersDir = Join-Path $specRoot "adapters"

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
$resolvedProfile = Resolve-Profile -RepoPath $resolvedRepoRoot -RequestedProfile $Profile
$repoName = Split-Path $resolvedRepoRoot -Leaf
$harnessDir = Join-Path $resolvedRepoRoot ".harness"
$selectedProfilePath = Join-Path $profilesDir "$resolvedProfile.yaml"
$selectedAdapterPath = Join-Path $adaptersDir "$Adapter.md"

if (-not (Test-Path $selectedProfilePath)) {
    throw "Profile not found: $selectedProfilePath"
}
if (-not (Test-Path $selectedAdapterPath)) {
    throw "Adapter not found: $selectedAdapterPath"
}

$defaults = Get-DefaultCommands -SelectedProfile $resolvedProfile

if ($DetectOnly) {
    Write-Host "Harness profile detection complete."
    Write-Host "Repo:     $resolvedRepoRoot"
    Write-Host "Profile:  $resolvedProfile"
    Write-Host "Adapter:  $Adapter"
    Write-Host "Build:    $($defaults.Build)"
    Write-Host "Test:     $($defaults.Test)"
    Write-Host "Mode:     detect-only"
    Write-Host ""
    Write-Host "No files were written."
    return
}

$profileLocalTemplatePath = Join-Path $templatesDir "profile.local.template.yaml"
if ($TaskId) {
    $moduleStatusTemplatePath = Join-Path $templatesDir "module-status.template.md"
    $moduleStatusTarget = Join-Path $harnessDir "module-status.md"
}

if ($DryRun) {
    Write-Host "plan  $harnessDir"
} else {
    New-Item -ItemType Directory -Path $harnessDir -Force | Out-Null
}

$templateMap = @(
    @{ Source = "scoped-map.template.md"; Target = "scoped-map.md" }
    @{ Source = "requirements.template.md"; Target = "requirements.md" }
    @{ Source = "architecture.template.md"; Target = "architecture.md" }
    @{ Source = "verification-path.template.md"; Target = "verification-path.md" }
    @{ Source = "module-status.template.md"; Target = "module-status.md" }
    @{ Source = "retrospective.template.md"; Target = "retrospective.md" }
)

$moduleStatusExisted = Test-Path (Join-Path $harnessDir "module-status.md")

foreach ($entry in $templateMap) {
    Copy-IfNeeded `
        -Source (Join-Path $templatesDir $entry.Source) `
        -Target (Join-Path $harnessDir $entry.Target) `
        -Overwrite $Force.IsPresent
}

Copy-IfNeeded `
    -Source $selectedProfilePath `
    -Target (Join-Path $harnessDir "profile.base.yaml") `
    -Overwrite $Force.IsPresent

Copy-IfNeeded `
    -Source $selectedAdapterPath `
    -Target (Join-Path $harnessDir "adapter-reference.md") `
    -Overwrite $Force.IsPresent

$profileLocalTarget = Join-Path $harnessDir "profile.local.yaml"

if ((-not (Test-Path $profileLocalTarget)) -or $Force.IsPresent) {
    $profileLocalContent = Get-Content $profileLocalTemplatePath -Raw
    $profileLocalContent = $profileLocalContent.Replace("__REPO_NAME__", $repoName)
    $profileLocalContent = $profileLocalContent.Replace("__BASE_PROFILE__", $resolvedProfile)
    $profileLocalContent = $profileLocalContent.Replace("__ADAPTER__", $Adapter)
    $profileLocalContent = $profileLocalContent.Replace("__BUILD_COMMAND__", $defaults.Build)
    $profileLocalContent = $profileLocalContent.Replace("__TEST_COMMAND__", $defaults.Test)
    $profileLocalContent = $profileLocalContent.Replace("__OPTIONAL_STATIC_CHECK__", $defaults.OptionalStaticCheck)
    $profileLocalContent = $profileLocalContent.Replace("__HIGH_RISK_PATH_1__", $defaults.HighRisk[0])
    $profileLocalContent = $profileLocalContent.Replace("__HIGH_RISK_PATH_2__", $defaults.HighRisk[1])
    $profileLocalContent = $profileLocalContent.Replace("__REPO_NOTE__", "Review and refine commands before the first generator task.")
    if ($DryRun) {
        Write-Host "plan  $profileLocalTarget"
    } else {
        Set-Content -Path $profileLocalTarget -Value $profileLocalContent
        Write-Host "write $profileLocalTarget"
    }
} else {
    Write-Host "skip  $profileLocalTarget"
}

if ($TaskId -and ((-not $moduleStatusExisted) -or $Force.IsPresent)) {
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    $moduleStatusContent = Get-Content $moduleStatusTemplatePath -Raw
    $moduleStatusContent = $moduleStatusContent.Replace("<task-id>", $TaskId)
    $moduleStatusContent = $moduleStatusContent.Replace("<role>", "repo-explorer")
    $moduleStatusContent = $moduleStatusContent.Replace("<state>", "exploring")
    $moduleStatusContent = $moduleStatusContent.Replace("<timestamp>", $timestamp)
    $moduleStatusContent = $moduleStatusContent.Replace("<notes>", "initial task row created by init-harness bootstrap")

    if ($DryRun) {
        Write-Host "plan  $moduleStatusTarget (seed first task row)"
    } else {
        Set-Content -Path $moduleStatusTarget -Value $moduleStatusContent
        Write-Host "write $moduleStatusTarget (seed first task row)"
    }
}

Write-Host ""
Write-Host "Harness bootstrap complete."
Write-Host "Repo:     $resolvedRepoRoot"
Write-Host "Profile:  $resolvedProfile"
Write-Host "Adapter:  $Adapter"
if ($TaskId) {
    Write-Host "TaskId:   $TaskId"
}
if ($DryRun) {
    Write-Host "Mode:     dry-run"
}
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Review .harness/profile.local.yaml"
Write-Host "2. Run Repo Explorer"
Write-Host "3. Run Verification Path Check before Generator"
