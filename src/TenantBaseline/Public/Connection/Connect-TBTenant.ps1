function Connect-TBTenant {
    <#
    .SYNOPSIS
        Connects to Microsoft Graph with the scopes required for UTCM operations.
    .DESCRIPTION
        Wraps Connect-MgGraph to establish a Microsoft Graph session for tenant
        configuration management. Supports delegated interactive sign-in for
        local/admin usage and unattended authentication modes for automation
        scenarios such as Azure Automation, GitHub Actions, and scheduled
        runners. Supports national/government cloud environments via the
        -Environment parameter. After a successful connection the module-scoped
        API base URI is updated automatically based on the active Graph
        environment.
    .PARAMETER TenantId
        The tenant ID to connect to. Used by delegated, app certificate, and
        client secret authentication. If not specified for delegated auth, uses
        the default tenant.
    .PARAMETER Scenario
        Delegated authentication scope profile:
        - ReadOnly: ConfigurationMonitoring.Read.All
        - Manage: ConfigurationMonitoring.ReadWrite.All
        - Setup: Manage + Application.ReadWrite.All + AppRoleAssignment.ReadWrite.All
    .PARAMETER Scopes
        Additional delegated scopes to request beyond the selected scenario
        scopes.
    .PARAMETER IncludeDirectoryMetadata
        Delegated-only option that requests optional directory metadata scopes
        (Organization.Read.All and Domain.Read.All) and attempts to resolve
        tenant display name and primary domain for friendly identity labels.
    .PARAMETER UseDeviceCode
        Delegated-only option that uses the device code flow instead of opening
        a browser window.
    .PARAMETER ClientId
        The application or managed identity client ID for unattended
        authentication modes.
    .PARAMETER CertificateThumbprint
        App-certificate authentication: certificate thumbprint in the current
        user's certificate store.
    .PARAMETER CertificateSubjectName
        App-certificate authentication: certificate subject name in the current
        user's certificate store.
    .PARAMETER Certificate
        App-certificate authentication: X509 certificate object to present.
    .PARAMETER ClientSecretCredential
        Client secret credential for app-only authentication. Supply a
        PSCredential whose username is the client ID and whose password is the
        client secret.
    .PARAMETER Identity
        Uses managed identity authentication for unattended execution.
    .PARAMETER AccessToken
        Uses a pre-acquired Microsoft Graph access token.
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
    .EXAMPLE
        Connect-TBTenant -Identity
        Connects using the ambient managed identity.
    .EXAMPLE
        Connect-TBTenant -ClientId '11111111-1111-1111-1111-111111111111' -TenantId 'contoso.onmicrosoft.com' -CertificateThumbprint 'ABC123...'
        Connects using app-only certificate authentication.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Delegated')]
    param(
        [Parameter(ParameterSetName = 'Delegated')]
        [Parameter(ParameterSetName = 'AppCertificate')]
        [Parameter(ParameterSetName = 'ClientSecret')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'Delegated')]
        [ValidateSet('ReadOnly', 'Manage', 'Setup')]
        [string]$Scenario = 'Manage',

        [Parameter(ParameterSetName = 'Delegated')]
        [string[]]$Scopes,

        [Parameter(ParameterSetName = 'Delegated')]
        [switch]$IncludeDirectoryMetadata,

        [Parameter(ParameterSetName = 'Delegated')]
        [switch]$UseDeviceCode,

        [Parameter(ParameterSetName = 'AppCertificate', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [string]$ClientId,

        [Parameter(ParameterSetName = 'AppCertificate')]
        [string]$CertificateThumbprint,

        [Parameter(ParameterSetName = 'AppCertificate')]
        [string]$CertificateSubjectName,

        [Parameter(ParameterSetName = 'AppCertificate')]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(ParameterSetName = 'ClientSecret', Mandatory = $true)]
        [pscredential]$ClientSecretCredential,

        [Parameter(ParameterSetName = 'ManagedIdentity', Mandatory = $true)]
        [switch]$Identity,

        [Parameter(ParameterSetName = 'AccessToken', Mandatory = $true)]
        [securestring]$AccessToken,

        [Parameter(ParameterSetName = 'Delegated')]
        [Parameter(ParameterSetName = 'AppCertificate')]
        [Parameter(ParameterSetName = 'ClientSecret')]
        [Parameter(ParameterSetName = 'ManagedIdentity')]
        [Parameter(ParameterSetName = 'AccessToken')]
        [ValidateSet('Global', 'USGov', 'USGovDoD', 'China')]
        [string]$Environment = 'Global'
    )

    $connectParams = @{
        NoWelcome   = $true
        Environment = $Environment
    }

    $authType = switch ($PSCmdlet.ParameterSetName) {
        'Delegated' { 'Delegated' }
        'AppCertificate' { 'AppCertificate' }
        'ClientSecret' { 'ClientSecret' }
        'ManagedIdentity' { 'ManagedIdentity' }
        'AccessToken' { 'AccessToken' }
    }

    $requestedScopes = @()

    switch ($PSCmdlet.ParameterSetName) {
        'Delegated' {
            $defaultScopes = switch ($Scenario) {
                'ReadOnly' { @('ConfigurationMonitoring.Read.All') }
                'Manage' { @('ConfigurationMonitoring.ReadWrite.All') }
                'Setup' { @('ConfigurationMonitoring.ReadWrite.All', 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All') }
            }

            $requestedScopes = @($defaultScopes)

            if ($IncludeDirectoryMetadata) {
                $requestedScopes += @(
                    'Organization.Read.All'
                    'Domain.Read.All'
                )
            }

            if ($Scopes) {
                $requestedScopes += $Scopes
            }

            $requestedScopes = $requestedScopes | Select-Object -Unique
            $connectParams['Scopes'] = $requestedScopes

            if ($TenantId) {
                $connectParams['TenantId'] = $TenantId
            }

            if ($UseDeviceCode) {
                $connectParams['UseDeviceCode'] = $true
            }

            Write-TBLog -Message ('Connecting to Microsoft Graph ({0}) using delegated auth with scopes: {1}' -f $Environment, ($requestedScopes -join ', '))
        }
        'AppCertificate' {
            if (-not ($CertificateThumbprint -or $CertificateSubjectName -or $Certificate)) {
                throw 'App certificate authentication requires -CertificateThumbprint, -CertificateSubjectName, or -Certificate.'
            }

            $connectParams['ClientId'] = $ClientId
            if ($TenantId) {
                $connectParams['TenantId'] = $TenantId
            }
            if ($CertificateThumbprint) {
                $connectParams['CertificateThumbprint'] = $CertificateThumbprint
            }
            if ($CertificateSubjectName) {
                $connectParams['CertificateSubjectName'] = $CertificateSubjectName
            }
            if ($Certificate) {
                $connectParams['Certificate'] = $Certificate
            }

            Write-TBLog -Message ('Connecting to Microsoft Graph ({0}) using app certificate auth for client {1}' -f $Environment, $ClientId)
        }
        'ClientSecret' {
            $connectParams['ClientSecretCredential'] = $ClientSecretCredential
            if ($TenantId) {
                $connectParams['TenantId'] = $TenantId
            }

            Write-TBLog -Message ('Connecting to Microsoft Graph ({0}) using client secret auth for client {1}' -f $Environment, $ClientSecretCredential.UserName)
        }
        'ManagedIdentity' {
            if ($Identity) {
                $connectParams['Identity'] = $true
            }
            if ($ClientId) {
                $connectParams['ClientId'] = $ClientId
            }

            Write-TBLog -Message ('Connecting to Microsoft Graph ({0}) using managed identity{1}' -f $Environment, $(if ($ClientId) { " client $ClientId" } else { '' }))
        }
        'AccessToken' {
            $connectParams['AccessToken'] = $AccessToken

            Write-TBLog -Message ('Connecting to Microsoft Graph ({0}) using a supplied access token' -f $Environment)
        }
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
            Scopes                   = if ($context.Scopes) { $context.Scopes } else { $requestedScopes }
            ConnectedAt              = Get-Date
            DirectoryMetadataEnabled = [bool]($PSCmdlet.ParameterSetName -eq 'Delegated' -and $IncludeDirectoryMetadata)
            TenantDisplayName        = $tenantDisplayName
            PrimaryDomain            = $primaryDomain
            Environment              = $Environment
            AuthType                 = $authType
            ClientId                 = $ClientId
        }

        Write-TBLog -Message ('Connected to tenant {0} using {1} authentication{2}' -f $context.TenantId, $authType, $(if ($context.Account) { " as $($context.Account)" } else { '' }))
        Write-Output ('Connected to tenant {0}' -f $context.TenantId)
    }
    catch {
        Write-TBLog -Message ('Failed to connect: {0}' -f $_) -Level 'Error'
        throw
    }
}
