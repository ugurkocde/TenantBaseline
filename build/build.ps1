#Requires -Version 7.2
<#
.SYNOPSIS
    Build script for TenantBaseline module. Runs lint and tests.
.DESCRIPTION
    Installs required tools, runs PSScriptAnalyzer, and executes Pester tests.
.PARAMETER SkipLint
    Skip PSScriptAnalyzer analysis.
.PARAMETER SkipTests
    Skip Pester test execution.
#>
[CmdletBinding()]
param(
    [switch]$SkipLint,
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$srcPath = Join-Path -Path $projectRoot -ChildPath 'src/TenantBaseline'
$testPath = Join-Path -Path $projectRoot -ChildPath 'tests/Unit'

Write-Host '--- TenantBaseline Build ---' -ForegroundColor Cyan

# Ensure dependencies
Write-Host 'Checking dependencies...' -ForegroundColor Yellow

if (-not (Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge '5.0.0' })) {
    Write-Host 'Installing Pester...'
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -Scope CurrentUser
}

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host 'Installing PSScriptAnalyzer...'
    Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
}

# Lint
if (-not $SkipLint) {
    Write-Host "`nRunning PSScriptAnalyzer..." -ForegroundColor Yellow
    $lintResults = Invoke-ScriptAnalyzer -Path $srcPath -Recurse -ExcludeRule PSUseShouldProcessForStateChangingFunctions
    if ($lintResults) {
        $lintResults | Format-Table RuleName, Severity, ScriptName, Line, Message -AutoSize
        $errors = $lintResults | Where-Object Severity -eq 'Error'
        if ($errors) {
            throw 'PSScriptAnalyzer found errors. Fix them before proceeding.'
        }
        Write-Host ('PSScriptAnalyzer: {0} warning(s), 0 error(s)' -f $lintResults.Count) -ForegroundColor Yellow
    }
    else {
        Write-Host 'PSScriptAnalyzer: No issues found.' -ForegroundColor Green
    }
}

# Tests
if (-not $SkipTests) {
    Write-Host "`nRunning Pester tests..." -ForegroundColor Yellow
    $config = New-PesterConfiguration
    $config.Run.Path = $testPath
    $config.Output.Verbosity = 'Detailed'
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputPath = Join-Path -Path $projectRoot -ChildPath 'testResults.xml'
    $config.TestResult.OutputFormat = 'NUnitXml'

    $result = Invoke-Pester -Configuration $config
    if ($result.FailedCount -gt 0) {
        throw ('{0} test(s) failed.' -f $result.FailedCount)
    }
    Write-Host ('Pester: {0} passed, {1} failed' -f $result.PassedCount, $result.FailedCount) -ForegroundColor Green
}

Write-Host "`n--- Build Complete ---" -ForegroundColor Cyan
