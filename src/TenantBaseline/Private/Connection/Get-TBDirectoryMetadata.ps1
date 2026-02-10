function Get-TBDirectoryMetadata {
    <#
    .SYNOPSIS
        Retrieves optional directory metadata used for friendly tenant identity.
    .DESCRIPTION
        Attempts to read tenant display name and default domain. Returns null
        fields when permissions are missing or metadata cannot be resolved.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $tenantDisplayName = $null
    $primaryDomain = $null

    try {
        $organization = $null
        if (Get-Command -Name Get-MgOrganization -ErrorAction SilentlyContinue) {
            $organization = Get-MgOrganization -Property DisplayName -ErrorAction Stop | Select-Object -First 1
        }
        else {
            $orgResponse = Invoke-MgGraphRequest -Uri "$(Get-TBGraphBaseUri)/v1.0/organization?`$select=displayName" -Method GET -ErrorAction Stop
            if ($orgResponse.value) {
                $organization = @($orgResponse.value)[0]
            }
            else {
                $organization = $orgResponse
            }
        }

        if ($organization -and $organization.DisplayName) {
            $tenantDisplayName = [string]$organization.DisplayName
        }
    }
    catch {
        Write-TBLog -Message ('Directory metadata lookup skipped (organization): {0}' -f $_.Exception.Message) -Level 'Warning'
    }

    try {
        $domain = $null
        if (Get-Command -Name Get-MgDomain -ErrorAction SilentlyContinue) {
            $domain = Get-MgDomain -Filter 'isDefault eq true' -Property Id,IsDefault -ErrorAction Stop | Select-Object -First 1
        }
        else {
            $domainResponse = Invoke-MgGraphRequest -Uri "$(Get-TBGraphBaseUri)/v1.0/domains?`$filter=isDefault eq true&`$select=id,isDefault" -Method GET -ErrorAction Stop
            if ($domainResponse.value) {
                $domain = @($domainResponse.value)[0]
            }
        }

        if ($domain -and $domain.Id) {
            $primaryDomain = [string]$domain.Id
        }
    }
    catch {
        Write-TBLog -Message ('Directory metadata lookup skipped (domain): {0}' -f $_.Exception.Message) -Level 'Warning'
    }

    return [PSCustomObject]@{
        TenantDisplayName = $tenantDisplayName
        PrimaryDomain     = $primaryDomain
    }
}
