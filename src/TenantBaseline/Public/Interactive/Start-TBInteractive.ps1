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
        # Check for an existing Graph session first
        try {
            $existingContext = Get-MgContext
        }
        catch {
            $existingContext = $null
        }

        if ($existingContext -and $existingContext.TenantId) {
            # Adopt the existing session -- update the API base URI to match the environment
            $script:TBApiBaseUri = "$(Get-TBGraphBaseUri)/beta/admin/configurationManagement"
            $existingEnv = if ($existingContext.Environment) { $existingContext.Environment } else { 'Global' }
            $script:TBConnection = [PSCustomObject]@{
                TenantId                 = $existingContext.TenantId
                Account                  = $existingContext.Account
                Scopes                   = $existingContext.Scopes
                ConnectedAt              = Get-Date
                DirectoryMetadataEnabled = $false
                TenantDisplayName        = $null
                PrimaryDomain            = $null
                Environment              = $existingEnv
            }
            break
        }

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
                Write-Host ''
                Write-Host '  Are you connecting to a government or national cloud?' -ForegroundColor Yellow
                Write-Host '  [1] Yes - GCC High (USGov)' -ForegroundColor Cyan
                Write-Host '  [2] Yes - DoD (USGovDoD)' -ForegroundColor Cyan
                Write-Host '  [3] Yes - China (21Vianet)' -ForegroundColor Cyan
                Write-Host '  [4] No - retry Global sign-in' -ForegroundColor Cyan
                Write-Host '  [5] Exit' -ForegroundColor Cyan

                $cloudChoice = Read-Host -Prompt '  Choose an option (1-5)'
                $selectedEnv = $null
                switch -Regex ($cloudChoice) {
                    '^1' { $selectedEnv = 'USGov' }
                    '^2' { $selectedEnv = 'USGovDoD' }
                    '^3' { $selectedEnv = 'China' }
                    '^4' { continue }
                    '^5' {
                        Write-Host ''
                        Write-Host '  Exiting interactive mode.' -ForegroundColor DarkGray
                        Write-Host ''
                        return
                    }
                    default { continue }
                }

                if ($selectedEnv) {
                    try {
                        Connect-TBTenant -Environment $selectedEnv
                        $lastError = $null
                        $connectedDuringThisLaunch = $true
                    }
                    catch {
                        $lastError = $_.Exception.Message
                        Write-Host ('  Connection failed: {0}' -f $lastError) -ForegroundColor Red
                    }
                }
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
        Write-Host '  Checking UTCM service principal status...' -ForegroundColor Cyan
        try {
            $spExists = Test-TBServicePrincipal
            if ($spExists) {
                Write-Host '  UTCM service principal: INSTALLED' -ForegroundColor Green
            }
            else {
                Write-Host '  UTCM service principal: NOT FOUND' -ForegroundColor Red
                Write-Host '  The UTCM service principal is required for monitors and snapshots.' -ForegroundColor Yellow
                Write-Host '  Installing requires Global Administrator or Application Administrator role.' -ForegroundColor Yellow
                Write-Host ''
                $installChoice = Read-Host -Prompt '  Install the UTCM service principal now? (Y/n)'
                if ($installChoice -notmatch '^[Nn]') {
                    try {
                        $result = Install-TBServicePrincipal -Confirm:$false
                        Write-Host ''
                        Write-Host ('  Service Principal ID: {0}' -f $result.Id) -ForegroundColor Green
                        if ($result.AlreadyExisted) {
                            Write-Host '  (Already existed)' -ForegroundColor Yellow
                        }
                        else {
                            Write-Host '  Successfully installed.' -ForegroundColor Green
                        }
                    }
                    catch {
                        Write-Host ('  Installation failed: {0}' -f $_.Exception.Message) -ForegroundColor Red
                        Write-Host '  You can retry from Setup and Permissions in the main menu.' -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Host '  You can install it later from Setup and Permissions in the main menu.' -ForegroundColor DarkGray
                }
            }
        }
        catch {
            Write-Host ('  Could not check service principal: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
        }
        Write-Host ''
    }

    Show-TBMainMenu
    Write-Host ''
    Write-Host '  Goodbye.' -ForegroundColor Cyan
    Write-Host ''
}
