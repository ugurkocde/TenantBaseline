function Get-TBDrift {
    <#
    .SYNOPSIS
        Lists configuration drifts detected by monitors.
    .DESCRIPTION
        Retrieves detected configuration drifts from the UTCM API.
        Can filter by drift ID or monitor ID.
    .PARAMETER DriftId
        The ID of a specific drift to retrieve.
    .PARAMETER MonitorId
        Filter drifts by monitor ID.
    .PARAMETER Top
        Maximum number of results to return.
    .EXAMPLE
        Get-TBDrift
        Lists all detected drifts.
    .EXAMPLE
        Get-TBDrift -MonitorId '00000000-...'
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [string]$DriftId,

        [Parameter(ParameterSetName = 'List')]
        [string]$MonitorId,

        [Parameter(ParameterSetName = 'List')]
        [int]$Top
    )

    $baseUri = Get-TBApiBaseUri

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $uri = '{0}/configurationDrifts/{1}' -f $baseUri, $DriftId
        Write-TBLog -Message ('Getting drift: {0}' -f $DriftId)
        $response = Invoke-TBGraphRequest -Uri $uri -Method 'GET'
        return ConvertFrom-TBDriftResponse -Response $response
    }

    $uri = '{0}/configurationDrifts' -f $baseUri
    $filters = [System.Collections.ArrayList]::new()
    $queryParams = [System.Collections.ArrayList]::new()

    if ($MonitorId) {
        $null = $filters.Add("monitorId eq '$MonitorId'")
    }

    if ($filters.Count -gt 0) {
        $null = $queryParams.Add('$filter={0}' -f ($filters -join ' and '))
    }

    if ($Top -gt 0) {
        $null = $queryParams.Add("`$top=$Top")
    }

    if ($queryParams.Count -gt 0) {
        $uri = '{0}?{1}' -f $uri, ($queryParams -join '&')
    }

    Write-TBLog -Message ('Listing drifts: {0}' -f $uri)
    $items = Invoke-TBGraphPagedRequest -Uri $uri

    foreach ($item in $items) {
        ConvertFrom-TBDriftResponse -Response $item
    }
}
