function Connect-TBTenant {
    <#
    .SYNOPSIS
        Connects to Microsoft Graph with the scopes required for UTCM operations.
    .DESCRIPTION
        Wraps Connect-MgGraph to establish a delegated authentication session
        with the minimum scopes needed for tenant configuration management.
        Supports national/government cloud environments via the -Environment
        parameter. After a successful connection the module-scoped API base URI
        is updated automatically based on the active Graph environment.
    .PARAMETER TenantId
        The tenant ID to connect to. If not specified, uses the default tenant.
    .PARAMETER Scenario
        Authentication scope profile:
        - ReadOnly: ConfigurationMonitoring.Read.All
        - Manage: ConfigurationMonitoring.ReadWrite.All
        - Setup: Manage + Application.ReadWrite.All + AppRoleAssignment.ReadWrite.All
    .PARAMETER Scopes
        Additional scopes to request beyond the selected scenario scopes.
    .PARAMETER IncludeDirectoryMetadata
        Requests optional directory metadata scopes (Organization.Read.All and
        Domain.Read.All) and attempts to resolve tenant display name and
        primary domain for friendly identity labels.
    .PARAMETER Environment
        The Microsoft Graph cloud environment to connect to:
        - Global (default): Commercial cloud
        - USGov: GCC High (graph.microsoft.us)
        - USGovDoD: DoD (dod-graph.microsoft.us)
        - China: 21Vianet (microsoftgraph.chinacloudapi.cn)
    .EXAMPLE
        Connect-TBTenant
        Connects with Manage scopes to the Global cloud.
    .EXAMPLE
        Connect-TBTenant -Scenario Setup
        Connects with setup scopes required for service principal provisioning.
    .EXAMPLE
        Connect-TBTenant -TenantId 'contoso.onmicrosoft.com'
        Connects to a specific tenant.
    .EXAMPLE
        Connect-TBTenant -Environment USGov
        Connects to a GCC High tenant.
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
        [switch]$IncludeDirectoryMetadata,

        [Parameter()]
        [ValidateSet('Global', 'USGov', 'USGovDoD', 'China')]
        [string]$Environment = 'Global'
    )

    $defaultScopes = switch ($Scenario) {
        'ReadOnly' { @('ConfigurationMonitoring.Read.All') }
        'Manage' { @('ConfigurationMonitoring.ReadWrite.All') }
        'Setup' { @('ConfigurationMonitoring.ReadWrite.All', 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All') }
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

    Write-TBLog -Message ('Connecting to Microsoft Graph ({0}) with scopes: {1}' -f $Environment, ($allScopes -join ', '))

    $connectParams = @{
        Scopes      = $allScopes
        NoWelcome   = $true
        Environment = $Environment
    }

    if ($TenantId) {
        $connectParams['TenantId'] = $TenantId
    }

    try {
        Connect-MgGraph @connectParams
        $context = Get-MgContext

        $script:TBApiBaseUri = "$(Get-TBGraphBaseUri)/beta/admin/configurationManagement"

        if ($Environment -ne 'Global') {
            Write-TBLog -Message 'UTCM APIs are only available in the Global cloud; operations may fail.' -Level 'Warning'
        }

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
            Environment              = $Environment
        }

        Write-TBLog -Message ('Connected to tenant {0} as {1}' -f $context.TenantId, $context.Account)
        Write-Output ('Connected to tenant {0}' -f $context.TenantId)
    }
    catch {
        Write-TBLog -Message ('Failed to connect: {0}' -f $_) -Level 'Error'
        throw
    }
}
