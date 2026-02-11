function Get-TBReconnectScenarioFromStatus {
    <#
    .SYNOPSIS
        Infers the current connection scenario from granted scopes.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Status
    )

    $scopes = @()
    if ($Status.Scopes) {
        $scopes = @($Status.Scopes)
    }

    if ($scopes -contains 'Application.ReadWrite.All') {
        return 'Setup'
    }

    if (($scopes -contains 'ConfigurationMonitoring.Read.All') -and -not ($scopes -contains 'ConfigurationMonitoring.ReadWrite.All')) {
        return 'ReadOnly'
    }

    return 'Manage'
}

function Get-TBMainMenuCapabilityState {
    <#
    .SYNOPSIS
        Computes feature availability from current Graph scopes.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Status
    )

    $scopes = @()
    if ($Status.Scopes) {
        $scopes = @($Status.Scopes)
    }

    $hasReadWrite = $scopes -contains 'ConfigurationMonitoring.ReadWrite.All'
    $hasReadOnly = $scopes -contains 'ConfigurationMonitoring.Read.All'
    $hasMonitoringAccess = $hasReadWrite -or $hasReadOnly
    $hasSetupAccess = $scopes -contains 'Application.ReadWrite.All'

    return [PSCustomObject]@{
        HasMonitoringAccess = $hasMonitoringAccess
        HasSetupAccess      = $hasSetupAccess
        HasMetadataScopes   = [bool]$Status.DirectoryMetadataEnabled
    }
}

function Write-TBMainMenuCapabilitySummary {
    <#
    .SYNOPSIS
        Shows a "what can I do now" summary above main menu options.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Status,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Capabilities
    )

    $hasMonitoring = $Capabilities.HasMonitoringAccess
    $hasSetup      = $Capabilities.HasSetupAccess

    if ($hasMonitoring -or $hasSetup) {
        Write-Host '    Available:' -ForegroundColor Cyan -NoNewline
        $parts = @()
        if ($hasMonitoring) { $parts += 'Monitors, Baselines, Snapshots, Drift, Reports' }
        if ($hasSetup)      { $parts += 'Setup' }
        Write-Host (' {0}' -f ($parts -join ', ')) -ForegroundColor Cyan
    }
    else {
        Write-Host '    Available: Connection Status only' -ForegroundColor Yellow
    }

    if (-not $Capabilities.HasSetupAccess) {
        Write-Host '    Setup actions are locked (requires Application.ReadWrite.All).' -ForegroundColor DarkGray
    }

    if (-not $Capabilities.HasMonitoringAccess) {
        Write-Host '    Workload actions are locked (requires ConfigurationMonitoring.Read.All or ReadWrite.All).' -ForegroundColor DarkGray
    }

    Write-Host ''
}

function Show-TBLockedSectionMessage {
    <#
    .SYNOPSIS
        Displays a standard locked-section message.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SectionName,

        [Parameter(Mandatory = $true)]
        [string]$RequiredScopeHint
    )

    Write-Host ''
    Write-Host ('  {0} is currently locked.' -f $SectionName) -ForegroundColor Red
    Write-Host ('  Required: {0}' -f $RequiredScopeHint) -ForegroundColor Yellow
    Read-Host -Prompt '  Press Enter to continue' | Out-Null
}

function Get-TBMenuSectionTitle {
    <#
    .SYNOPSIS
        Returns the display title for a menu section, with lock suffix when needed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseTitle,

        [Parameter(Mandatory = $true)]
        [bool]$IsEnabled
    )

    if ($IsEnabled) {
        return $BaseTitle
    }

    return ('{0} [Locked]' -f $BaseTitle)
}

function Show-TBConnectionStatusPanel {
    <#
    .SYNOPSIS
        Renders connection status details and optional metadata-consent action.
    #>
    [CmdletBinding()]
    param()

    $showTechnicalDetails = $false

    while ($true) {
        Clear-Host
        Write-TBMenuHeader -Mode Rich
        Write-Host ''
        Write-Host '  -- Connection Status --' -ForegroundColor Cyan
        Write-Host ''

        try {
            $status = Get-TBConnectionStatus
        }
        catch {
            Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            Read-Host -Prompt '  Press Enter to return to the main menu' | Out-Null
            return
        }

        if ($status.Connected) {
            $identityLabel = Format-TBTenantIdentity -ConnectionStatus $status

            Write-Host '  Connected:         Yes' -ForegroundColor Green
            Write-Host ('  Organization:      {0}' -f $identityLabel) -ForegroundColor White
            Write-Host ('  Account:           {0}' -f $status.Account) -ForegroundColor White
            Write-Host ('  Connected At:      {0}' -f $status.ConnectedAt) -ForegroundColor White
            if ($status.Environment -and $status.Environment -ne 'Global') {
                $envLabel = switch ($status.Environment) {
                    'USGov'    { 'USGov (GCC High)' }
                    'USGovDoD' { 'USGovDoD (DoD)' }
                    'China'    { 'China (21Vianet)' }
                    default    { $status.Environment }
                }
                Write-Host ('  Environment:       {0}' -f $envLabel) -ForegroundColor Yellow
            }

            if ($showTechnicalDetails) {
                Write-Host ''
                Write-Host '  Technical details' -ForegroundColor DarkGray
                Write-Host ('  Tenant ID:         {0}' -f $status.TenantId) -ForegroundColor DarkGray
                if ($status.PrimaryDomain) {
                    Write-Host ('  Primary Domain:    {0}' -f $status.PrimaryDomain) -ForegroundColor DarkGray
                }
                if ($status.TenantDisplayName) {
                    Write-Host ('  Tenant Name:       {0}' -f $status.TenantDisplayName) -ForegroundColor DarkGray
                }

                if ($status.Scopes -and $status.Scopes.Count -gt 0) {
                    Write-Host ('  Scopes:            {0}' -f ($status.Scopes -join ', ')) -ForegroundColor DarkGray
                }
                else {
                    Write-Host '  Scopes:            (none reported)' -ForegroundColor DarkGray
                }
            }
            else {
                Write-Host ''
                Write-Host '  Technical details are hidden. Press T to show tenant ID and scopes.' -ForegroundColor DarkGray
            }
        }
        else {
            Write-Host '  Connected:         No' -ForegroundColor Red
            Write-Host '  Sign in to establish a Microsoft Graph connection.' -ForegroundColor Yellow
        }

        Write-Host ''
        if (-not $status.Connected) {
            Write-Host '  [S] Sign in now' -ForegroundColor Cyan
        }
        elseif (-not $status.DirectoryMetadataEnabled) {
            Write-Host '  [D] Enable organization metadata (primary domain/display name)' -ForegroundColor Cyan
        }

        if ($showTechnicalDetails) {
            Write-Host '  [T] Hide technical details' -ForegroundColor Cyan
        }
        else {
            Write-Host '  [T] Show technical details' -ForegroundColor Cyan
        }
        Write-Host '  [Enter] Back to main menu' -ForegroundColor Cyan

        $choice = Read-Host -Prompt '  Choose an action'
        if ([string]::IsNullOrWhiteSpace($choice)) {
            return
        }

        if ($choice -match '^[Tt]') {
            $showTechnicalDetails = -not $showTechnicalDetails
            continue
        }

        if (($choice -match '^[Ss]') -and -not $status.Connected) {
            $signInParams = @{}
            if ($status.Environment) {
                $signInParams['Environment'] = $status.Environment
            }
            try {
                Connect-TBTenant @signInParams | Out-Null
            }
            catch {
                Write-Host ('  Sign-in failed: {0}' -f $_.Exception.Message) -ForegroundColor Red
                Read-Host -Prompt '  Press Enter to continue' | Out-Null
            }
            continue
        }

        if (($choice -match '^[Dd]') -and $status.Connected -and -not $status.DirectoryMetadataEnabled) {
            $scenario = Get-TBReconnectScenarioFromStatus -Status $status
            $connectParams = @{
                Scenario                 = $scenario
                IncludeDirectoryMetadata = $true
            }
            if ($status.TenantId) {
                $connectParams['TenantId'] = $status.TenantId
            }
            if ($status.Environment) {
                $connectParams['Environment'] = $status.Environment
            }

            try {
                Connect-TBTenant @connectParams | Out-Null
                Write-Host '  Metadata consent completed and connection refreshed.' -ForegroundColor Green
                Read-Host -Prompt '  Press Enter to continue' | Out-Null
            }
            catch {
                Write-Host ('  Metadata consent failed: {0}' -f $_.Exception.Message) -ForegroundColor Red
                Read-Host -Prompt '  Press Enter to continue' | Out-Null
            }
            continue
        }

        Write-Host ''
        Write-Host '  Invalid option for current state.' -ForegroundColor Yellow
        Read-Host -Prompt '  Press Enter to continue' | Out-Null
    }
}

function Show-TBMainMenuClassic {
    <#
    .SYNOPSIS
        Classic main menu for non-interactive hosts.
    .DESCRIPTION
        Original numbered-prompt main menu loop. Used when arrow-key support
        is not available.
    #>
    [CmdletBinding()]
    param()

    while ($true) {
        Clear-Host
        Write-TBMenuHeader -Mode Rich

        $status = Get-TBConnectionStatus
        $capabilities = Get-TBMainMenuCapabilityState -Status $status
        Write-TBMainMenuCapabilitySummary -Status $status -Capabilities $capabilities

        $setupTitle = Get-TBMenuSectionTitle -BaseTitle 'Setup and Permissions' -IsEnabled $capabilities.HasSetupAccess
        $monitorTitle = Get-TBMenuSectionTitle -BaseTitle 'Monitor Management' -IsEnabled $capabilities.HasMonitoringAccess
        $baselineTitle = Get-TBMenuSectionTitle -BaseTitle 'Baseline Management' -IsEnabled $capabilities.HasMonitoringAccess
        $snapshotTitle = Get-TBMenuSectionTitle -BaseTitle 'Snapshot Management' -IsEnabled $capabilities.HasMonitoringAccess
        $driftTitle = Get-TBMenuSectionTitle -BaseTitle 'Drift Detection' -IsEnabled $capabilities.HasMonitoringAccess
        $reportTitle = Get-TBMenuSectionTitle -BaseTitle 'Reports and Documentation' -IsEnabled $capabilities.HasMonitoringAccess

        $options = @(
            'Connection Status'
            $setupTitle
            $monitorTitle
            $baselineTitle
            $snapshotTitle
            $driftTitle
            $reportTitle
        )

        $choice = Show-TBMenu -Title 'Main Menu' -Options $options -IncludeQuit
        if ($choice -eq 'Quit') { return }

        switch ($choice) {
            0 { Show-TBConnectionStatusPanel }
            1 {
                if (-not $capabilities.HasSetupAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Setup and Permissions' -RequiredScopeHint 'Application.ReadWrite.All (use Connect-TBTenant -Scenario Setup)'
                    continue
                }
                Show-TBSetupMenu
            }
            2 {
                if (-not $capabilities.HasMonitoringAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Monitor Management' -RequiredScopeHint 'ConfigurationMonitoring.Read.All or ConfigurationMonitoring.ReadWrite.All'
                    continue
                }
                Show-TBMonitorMenu
            }
            3 {
                if (-not $capabilities.HasMonitoringAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Baseline Management' -RequiredScopeHint 'ConfigurationMonitoring.Read.All or ConfigurationMonitoring.ReadWrite.All'
                    continue
                }
                Show-TBBaselineMenu
            }
            4 {
                if (-not $capabilities.HasMonitoringAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Snapshot Management' -RequiredScopeHint 'ConfigurationMonitoring.Read.All or ConfigurationMonitoring.ReadWrite.All'
                    continue
                }
                Show-TBSnapshotMenu
            }
            5 {
                if (-not $capabilities.HasMonitoringAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Drift Detection' -RequiredScopeHint 'ConfigurationMonitoring.Read.All or ConfigurationMonitoring.ReadWrite.All'
                    continue
                }
                Show-TBDriftMenu
            }
            6 {
                if (-not $capabilities.HasMonitoringAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Reports and Documentation' -RequiredScopeHint 'ConfigurationMonitoring.Read.All or ConfigurationMonitoring.ReadWrite.All'
                    continue
                }
                Show-TBReportMenu
            }
        }
    }
}

function Show-TBMainMenu {
    <#
    .SYNOPSIS
        Displays the top-level interactive menu.
    .DESCRIPTION
        Main navigation hub that routes to the various management submenus
        and shows connection status. On PS 7+ with interactive console support,
        uses an accordion-style menu. Falls back to classic numbered menus on
        non-interactive hosts.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-TBArrowKeySupport)) {
        Show-TBMainMenuClassic
        return
    }

    $lastExpanded = -1

    while ($true) {
        Clear-Host
        Write-TBMenuHeader -Mode Rich

        $status = Get-TBConnectionStatus
        $capabilities = Get-TBMainMenuCapabilityState -Status $status
        Write-TBMainMenuCapabilitySummary -Status $status -Capabilities $capabilities

        $setupTitle = Get-TBMenuSectionTitle -BaseTitle 'Setup and Permissions' -IsEnabled $capabilities.HasSetupAccess
        $monitorTitle = Get-TBMenuSectionTitle -BaseTitle 'Monitor Management' -IsEnabled $capabilities.HasMonitoringAccess
        $baselineTitle = Get-TBMenuSectionTitle -BaseTitle 'Baseline Management' -IsEnabled $capabilities.HasMonitoringAccess
        $snapshotTitle = Get-TBMenuSectionTitle -BaseTitle 'Snapshot Management' -IsEnabled $capabilities.HasMonitoringAccess
        $driftTitle = Get-TBMenuSectionTitle -BaseTitle 'Drift Detection' -IsEnabled $capabilities.HasMonitoringAccess
        $reportTitle = Get-TBMenuSectionTitle -BaseTitle 'Reports and Documentation' -IsEnabled $capabilities.HasMonitoringAccess

        $sections = @(
            @{
                Title    = 'Connection Status'
                Children = @()
                IsDirect = $true
            }
            @{
                Title    = $setupTitle
                Children = @(
                    'Install UTCM service principal'
                    'Check service principal status'
                    'Grant workload permissions'
                )
                IsDirect = $false
            }
            @{
                Title    = $monitorTitle
                Children = @(
                    'Create new monitor'
                    'Create from Maester'
                    'List monitors'
                    'View monitor details'
                    'Update monitor'
                    'Delete monitor'
                    'View monitor results'
                )
                IsDirect = $false
            }
            @{
                Title    = $baselineTitle
                Children = @(
                    'View baseline from monitor'
                    'Export baseline'
                    'Import baseline'
                )
                IsDirect = $false
            }
            @{
                Title    = $snapshotTitle
                Children = @(
                    'Create snapshot (selected types)'
                    'Create snapshot (entire workload)'
                    'Create snapshot (all workloads)'
                    'List snapshot jobs'
                    'View snapshot details'
                    'Export snapshot'
                    'Delete snapshot'
                )
                IsDirect = $false
            }
            @{
                Title    = $driftTitle
                Children = @(
                    'View all drifts'
                    'View drifts by monitor'
                    'Drift summary'
                    'View drift details'
                )
                IsDirect = $false
            }
            @{
                Title    = $reportTitle
                Children = @(
                    'Generate drift report'
                    'Generate dashboard'
                    'Generate documentation'
                )
                IsDirect = $false
            }
        )

        $result = Show-TBMenuArrowAccordion -Sections $sections -InitialExpanded $lastExpanded
        if ($result -eq 'Quit') { return }

        $lastExpanded = $result.Section
        Clear-Host

        switch ($result.Section) {
            0 { Show-TBConnectionStatusPanel }
            1 {
                if (-not $capabilities.HasSetupAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Setup and Permissions' -RequiredScopeHint 'Application.ReadWrite.All (use Connect-TBTenant -Scenario Setup)'
                    continue
                }
                Show-TBSetupMenu -DirectAction $result.Item
            }
            2 {
                if (-not $capabilities.HasMonitoringAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Monitor Management' -RequiredScopeHint 'ConfigurationMonitoring.Read.All or ConfigurationMonitoring.ReadWrite.All'
                    continue
                }
                Show-TBMonitorMenu -DirectAction $result.Item
            }
            3 {
                if (-not $capabilities.HasMonitoringAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Baseline Management' -RequiredScopeHint 'ConfigurationMonitoring.Read.All or ConfigurationMonitoring.ReadWrite.All'
                    continue
                }
                Show-TBBaselineMenu -DirectAction $result.Item
            }
            4 {
                if (-not $capabilities.HasMonitoringAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Snapshot Management' -RequiredScopeHint 'ConfigurationMonitoring.Read.All or ConfigurationMonitoring.ReadWrite.All'
                    continue
                }
                Show-TBSnapshotMenu -DirectAction $result.Item
            }
            5 {
                if (-not $capabilities.HasMonitoringAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Drift Detection' -RequiredScopeHint 'ConfigurationMonitoring.Read.All or ConfigurationMonitoring.ReadWrite.All'
                    continue
                }
                Show-TBDriftMenu -DirectAction $result.Item
            }
            6 {
                if (-not $capabilities.HasMonitoringAccess) {
                    Show-TBLockedSectionMessage -SectionName 'Reports and Documentation' -RequiredScopeHint 'ConfigurationMonitoring.Read.All or ConfigurationMonitoring.ReadWrite.All'
                    continue
                }
                Show-TBReportMenu -DirectAction $result.Item
            }
        }
    }
}
