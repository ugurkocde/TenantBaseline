function Test-TBServicePrincipal {
    <#
    .SYNOPSIS
        Checks if the UTCM service principal exists in the tenant.
    .DESCRIPTION
        Verifies whether the UTCM service principal has been provisioned
        and reports its current state.
    .EXAMPLE
        Test-TBServicePrincipal
        Returns $true if the SP exists, $false otherwise.
    .EXAMPLE
        if (-not (Test-TBServicePrincipal)) { Install-TBServicePrincipal }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $null = Test-TBGraphConnection

    $appId = $script:UTCMAppId

    try {
        $filterUri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$appId'"
        $response = Invoke-TBGraphRequest -Uri $filterUri -Method 'GET'

        $items = $null
        if ($response -is [hashtable] -and $response.ContainsKey('value')) {
            $items = $response['value']
        }
        elseif ($response.PSObject.Properties['value']) {
            $items = $response.value
        }

        if ($items -and @($items).Count -gt 0) {
            Write-TBLog -Message 'UTCM service principal found'
            return $true
        }
        else {
            Write-TBLog -Message 'UTCM service principal not found'
            return $false
        }
    }
    catch {
        Write-TBLog -Message ('Error checking service principal: {0}' -f $_) -Level 'Warning'
        return $false
    }
}
