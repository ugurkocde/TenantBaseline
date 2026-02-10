function Connect-TBTenant {
    <#
    .SYNOPSIS
        Connects to Microsoft Graph with the scopes required for UTCM operations.
    .DESCRIPTION
        Wraps Connect-MgGraph to establish a delegated authentication session
        with the minimum scopes needed for tenant configuration management.
    .PARAMETER TenantId
        The tenant ID to connect to. If not specified, uses the default tenant.
    .PARAMETER Scenario
        Authentication scope profile:
        - ReadOnly: ConfigurationMonitoring.Read.All
        - Manage: ConfigurationMonitoring.ReadWrite.All
        - Setup: Manage + Application.ReadWrite.All
    .PARAMETER Scopes
        Additional scopes to request beyond the selected scenario scopes.
    .PARAMETER IncludeDirectoryMetadata
        Requests optional directory metadata scopes (Organization.Read.All and
        Domain.Read.All) and attempts to resolve tenant display name and
        primary domain for friendly identity labels.
    .EXAMPLE
        Connect-TBTenant
        Connects with Manage scopes.
    .EXAMPLE
        Connect-TBTenant -Scenario Setup
        Connects with setup scopes required for service principal provisioning.
    .EXAMPLE
        Connect-TBTenant -TenantId 'contoso.onmicrosoft.com'
        Connects to a specific tenant.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [ValidateSet('ReadOnly', 'Manage', 'Setup')]
        [string]$Scenario = 'Manage',

        [Parameter()]
        [string[]]$Scopes,

        [Parameter()]
        [switch]$IncludeDirectoryMetadata
    )

    $defaultScopes = switch ($Scenario) {
        'ReadOnly' { @('ConfigurationMonitoring.Read.All') }
        'Manage' { @('ConfigurationMonitoring.ReadWrite.All') }
        'Setup' { @('ConfigurationMonitoring.ReadWrite.All', 'Application.ReadWrite.All') }
    }

    $allScopes = @($defaultScopes)

    if ($IncludeDirectoryMetadata) {
        $allScopes += @(
            'Organization.Read.All'
            'Domain.Read.All'
        )
    }

    if ($Scopes) {
        $allScopes += $Scopes
    }
    $allScopes = $allScopes | Select-Object -Unique

    Write-TBLog -Message ('Connecting to Microsoft Graph with scopes: {0}' -f ($allScopes -join ', '))

    $connectParams = @{
        Scopes = $allScopes
        NoWelcome = $true
    }

    if ($TenantId) {
        $connectParams['TenantId'] = $TenantId
    }

    try {
        Connect-MgGraph @connectParams
        $context = Get-MgContext

        $tenantDisplayName = $null
        $primaryDomain = $null
        if ($IncludeDirectoryMetadata) {
            try {
                $directoryMetadata = Get-TBDirectoryMetadata
                if ($directoryMetadata) {
                    $tenantDisplayName = $directoryMetadata.TenantDisplayName
                    $primaryDomain = $directoryMetadata.PrimaryDomain
                }
            }
            catch {
                Write-TBLog -Message ('Directory metadata enrichment failed: {0}' -f $_.Exception.Message) -Level 'Warning'
            }
        }

        $script:TBConnection = [PSCustomObject]@{
            TenantId                 = $context.TenantId
            Account                  = $context.Account
            Scopes                   = $context.Scopes
            ConnectedAt              = Get-Date
            DirectoryMetadataEnabled = [bool]$IncludeDirectoryMetadata
            TenantDisplayName        = $tenantDisplayName
            PrimaryDomain            = $primaryDomain
        }

        Write-TBLog -Message ('Connected to tenant {0} as {1}' -f $context.TenantId, $context.Account)
        Write-Output ('Connected to tenant {0}' -f $context.TenantId)
    }
    catch {
        Write-TBLog -Message ('Failed to connect: {0}' -f $_) -Level 'Error'
        throw
    }
}
