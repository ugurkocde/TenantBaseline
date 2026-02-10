function Get-TBConnectionStatus {
    <#
    .SYNOPSIS
        Returns the current Microsoft Graph connection status.
    .DESCRIPTION
        Shows whether a Graph session is active, the connected tenant, account,
        and granted scopes.
    .EXAMPLE
        Get-TBConnectionStatus
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    try {
        $context = Get-MgContext
    }
    catch {
        $context = $null
    }

    if (-not $context) {
        return [PSCustomObject]@{
            Connected                 = $false
            TenantId                  = $null
            Account                   = $null
            Scopes                    = @()
            ConnectedAt               = $null
            TenantDisplayName         = $null
            PrimaryDomain             = $null
            IdentityLabel             = $null
            DirectoryMetadataEnabled  = $false
        }
    }

    $connectionState = $script:TBConnection
    $connectedAt = $null
    if ($connectionState) {
        $connectedAt = $connectionState.ConnectedAt
    }

    $tenantDisplayName = $null
    if ($connectionState -and $connectionState.PSObject.Properties['TenantDisplayName']) {
        $tenantDisplayName = $connectionState.TenantDisplayName
    }

    $primaryDomain = $null
    if ($connectionState -and $connectionState.PSObject.Properties['PrimaryDomain']) {
        $primaryDomain = $connectionState.PrimaryDomain
    }

    $directoryMetadataEnabled = $false
    if ($connectionState -and $connectionState.PSObject.Properties['DirectoryMetadataEnabled']) {
        $directoryMetadataEnabled = [bool]$connectionState.DirectoryMetadataEnabled
    }
    elseif ($context.Scopes) {
        $directoryMetadataEnabled = (
            ($context.Scopes -contains 'Organization.Read.All') -and
            ($context.Scopes -contains 'Domain.Read.All')
        )
    }

    $accountDomain = $null
    if ($context.Account -and $context.Account -match '@') {
        $accountDomain = ($context.Account -split '@')[-1]
    }

    $identityLabel = $null
    if ($primaryDomain) {
        $identityLabel = $primaryDomain
    }
    elseif ($tenantDisplayName) {
        $identityLabel = $tenantDisplayName
    }
    elseif ($accountDomain) {
        $identityLabel = $accountDomain
    }
    elseif ($context.TenantId) {
        $identityLabel = $context.TenantId
    }
    else {
        $identityLabel = 'Unknown Tenant'
    }

    return [PSCustomObject]@{
        Connected                = $true
        TenantId                 = $context.TenantId
        Account                  = $context.Account
        Scopes                   = $context.Scopes
        ConnectedAt              = $connectedAt
        TenantDisplayName        = $tenantDisplayName
        PrimaryDomain            = $primaryDomain
        IdentityLabel            = $identityLabel
        DirectoryMetadataEnabled = $directoryMetadataEnabled
    }
}
