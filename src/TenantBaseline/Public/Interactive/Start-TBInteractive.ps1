function Start-TBInteractive {
    <#
    .SYNOPSIS
        Launches the TenantBaseline interactive management console.
    .DESCRIPTION
        Starts a menu-driven console interface for managing UTCM configuration
        monitors, snapshots, baselines, drift detection, and setup. Provides
        guided workflows with input validation and resource type pickers.

        On launch, checks for an active Microsoft Graph connection. If not
        connected, prompts the user to connect before entering the menu.
    .EXAMPLE
        Start-TBInteractive
        Launches the interactive console.
    #>
    [CmdletBinding()]
    param()

    $lastError = $null
    $connectedDuringThisLaunch = $false
    while ($true) {
        $status = Get-TBConnectionStatus
        if ($status.Connected) {
            break
        }

        Write-Host ''
        Write-Host '  TenantBaseline interactive console' -ForegroundColor Cyan
        Write-Host '  Sign-in is required before opening the main menu.' -ForegroundColor Yellow
        if ($lastError) {
            Write-Host ('  Last error: {0}' -f $lastError) -ForegroundColor Red
        }
        Write-Host ''
        Write-Host '  [1] Sign in' -ForegroundColor Cyan
        Write-Host '  [2] Exit interactive mode' -ForegroundColor Cyan

        $response = Read-Host -Prompt '  Choose an option (1/2)'
        if ($response -match '^1') {
            Write-Host ''
            try {
                Connect-TBTenant
                $lastError = $null
                $connectedDuringThisLaunch = $true
            }
            catch {
                $lastError = $_.Exception.Message
                Write-Host ('  Connection failed: {0}' -f $lastError) -ForegroundColor Red
            }
            continue
        }

        if ($response -match '^2') {
            Write-Host ''
            Write-Host '  Exiting interactive mode.' -ForegroundColor DarkGray
            Write-Host ''
            return
        }

        Write-Host ''
        Write-Host '  Invalid option. Enter 1 or 2.' -ForegroundColor Yellow
    }

    if ($connectedDuringThisLaunch) {
        Write-Host ''
        Write-Host '  Quick Start (recommended)' -ForegroundColor Cyan
        Write-Host '  1) Setup check  2) Create first monitor' -ForegroundColor DarkGray
        $quickStartChoice = Read-Host -Prompt '  Run quick start now? (y/N)'
        if ($quickStartChoice -match '^[Yy]') {
            Invoke-TBQuickStart
        }
    }

    Show-TBMainMenu
    Write-Host ''
    Write-Host '  Goodbye.' -ForegroundColor Cyan
    Write-Host ''
}
