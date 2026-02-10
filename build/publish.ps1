#Requires -Version 7.2
<#
.SYNOPSIS
    Publishes the TenantBaseline module to the PowerShell Gallery.
.DESCRIPTION
    Runs the build script first, then publishes the module.
.PARAMETER NuGetApiKey
    The PSGallery API key. Can also be set via NUGET_API_KEY environment variable.
.PARAMETER WhatIf
    Show what would be published without actually publishing.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string]$NuGetApiKey
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$srcPath = Join-Path -Path $projectRoot -ChildPath 'src/TenantBaseline'

if (-not $NuGetApiKey) {
    $NuGetApiKey = $env:NUGET_API_KEY
}

if (-not $NuGetApiKey) {
    throw 'NuGetApiKey is required. Pass it as a parameter or set the NUGET_API_KEY environment variable.'
}

# Run build first
Write-Host 'Running build...' -ForegroundColor Cyan
$buildScript = Join-Path -Path $PSScriptRoot -ChildPath 'build.ps1'
& $buildScript

# Publish
if ($PSCmdlet.ShouldProcess('PSGallery', 'Publish TenantBaseline module')) {
    Write-Host "`nPublishing to PSGallery..." -ForegroundColor Yellow
    Publish-Module -Path $srcPath -NuGetApiKey $NuGetApiKey -Verbose
    Write-Host 'Published successfully.' -ForegroundColor Green
}
