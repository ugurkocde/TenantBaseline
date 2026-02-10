function Format-TBTenantIdentity {
    <#
    .SYNOPSIS
        Returns a human-friendly tenant identity label for interactive UI.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ConnectionStatus
    )

    if ($ConnectionStatus.PSObject.Properties['IdentityLabel'] -and $ConnectionStatus.IdentityLabel) {
        return [string]$ConnectionStatus.IdentityLabel
    }

    if ($ConnectionStatus.PSObject.Properties['PrimaryDomain'] -and $ConnectionStatus.PrimaryDomain) {
        return [string]$ConnectionStatus.PrimaryDomain
    }

    if ($ConnectionStatus.PSObject.Properties['TenantDisplayName'] -and $ConnectionStatus.TenantDisplayName) {
        return [string]$ConnectionStatus.TenantDisplayName
    }

    if ($ConnectionStatus.PSObject.Properties['Account'] -and $ConnectionStatus.Account -and $ConnectionStatus.Account -match '@') {
        return [string](($ConnectionStatus.Account -split '@')[-1])
    }

    if ($ConnectionStatus.PSObject.Properties['TenantId'] -and $ConnectionStatus.TenantId) {
        return [string]$ConnectionStatus.TenantId
    }

    return 'Unknown Tenant'
}
