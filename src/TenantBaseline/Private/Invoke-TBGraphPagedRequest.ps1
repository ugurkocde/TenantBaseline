function Invoke-TBGraphPagedRequest {
    <#
    .SYNOPSIS
        Follows @odata.nextLink to retrieve complete Graph collections.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    $allItems = [System.Collections.ArrayList]::new()
    $nextUri = $Uri

    while ($nextUri) {
        $response = Invoke-TBGraphRequest -Uri $nextUri -Method 'GET'

        $items = @()
        if ($response -is [hashtable] -and $response.ContainsKey('value')) {
            $items = @($response['value'])
        }
        elseif ($response.PSObject.Properties['value']) {
            $items = @($response.value)
        }
        else {
            $items = @($response)
        }

        foreach ($item in $items) {
            $null = $allItems.Add($item)
        }

        $nextUri = $null
        if ($response -is [hashtable]) {
            if ($response.ContainsKey('@odata.nextLink')) {
                $nextUri = $response['@odata.nextLink']
            }
            elseif ($response.ContainsKey('odata.nextLink')) {
                $nextUri = $response['odata.nextLink']
            }
        }
        else {
            if ($response.PSObject.Properties['@odata.nextLink']) {
                $nextUri = $response.'@odata.nextLink'
            }
            elseif ($response.PSObject.Properties['odata.nextLink']) {
                $nextUri = $response.'odata.nextLink'
            }
        }
    }

    return @($allItems)
}
