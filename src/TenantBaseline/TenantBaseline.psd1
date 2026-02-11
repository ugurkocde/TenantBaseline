@{
    RootModule        = 'TenantBaseline.psm1'
    ModuleVersion     = '0.2.2'
    GUID              = 'edee0e7b-afeb-4cc1-b30c-ef8486d7c9a6'
    Author            = 'TenantBaseline Contributors'
    CompanyName       = 'Community'
    Copyright         = '(c) 2026 TenantBaseline Contributors. All rights reserved.'
    Description       = 'PowerShell module for Microsoft 365 tenant configuration monitoring using the Microsoft Graph UTCM beta API. Provides baseline management, drift detection, and configuration snapshots.'

    PowerShellVersion = '7.2'
    CompatiblePSEditions = @('Core')

    RequiredModules   = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' }
    )

    FunctionsToExport = @(
        # Connection
        'Connect-TBTenant'
        'Disconnect-TBTenant'
        'Get-TBConnectionStatus'

        # Setup
        'Install-TBServicePrincipal'
        'Test-TBServicePrincipal'
        'Grant-TBServicePrincipalPermission'
        'Get-TBPermissionPlan'

        # Monitor
        'New-TBMonitor'
        'Get-TBMonitor'
        'Set-TBMonitor'
        'Remove-TBMonitor'
        'Get-TBMonitorResult'

        # Drift
        'Get-TBDrift'
        'Get-TBDriftSummary'

        # Baseline
        'Get-TBBaseline'
        'Export-TBBaseline'
        'Import-TBBaseline'

        # Snapshot
        'New-TBSnapshot'
        'Get-TBSnapshot'
        'Remove-TBSnapshot'
        'Export-TBSnapshot'
        'Wait-TBSnapshot'

        # Report
        'New-TBDriftReport'
        'New-TBDashboard'
        'New-TBDocumentation'

        # Interactive
        'Start-TBInteractive'
    )

    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @('TenantBaseline')

    PrivateData = @{
        PSData = @{
            Tags         = @('Microsoft365', 'Graph', 'UTCM', 'Baseline', 'Drift', 'Security', 'Compliance', 'Intune', 'ConditionalAccess', 'EntraID')
            LicenseUri   = 'https://github.com/ugurkocde/TenantBaseline/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/ugurkocde/TenantBaseline'
            ReleaseNotes = 'Fix monitor creation: send required empty properties object for manual resource selection.'
        }
    }
}
