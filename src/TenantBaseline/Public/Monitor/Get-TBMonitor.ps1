function Get-TBMonitor {
    <#
    .SYNOPSIS
        Gets one or all configuration monitors.
    .DESCRIPTION
        Retrieves configuration monitors from the UTCM API. Can get a specific
        monitor by ID or list all monitors.
    .PARAMETER MonitorId
        The ID of a specific monitor to retrieve.
    .EXAMPLE
        Get-TBMonitor
        Lists all monitors.
    .EXAMPLE
        Get-TBMonitor -MonitorId '00000000-0000-0000-0000-000000000000'
        Gets a specific monitor.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$MonitorId
    )

    process {
        $baseUri = Get-TBApiBaseUri

        if ($MonitorId) {
            $uri = '{0}/configurationMonitors/{1}' -f $baseUri, $MonitorId
            Write-TBLog -Message ('Getting monitor: {0}' -f $MonitorId)
            $response = Invoke-TBGraphRequest -Uri $uri -Method 'GET'
            return ConvertFrom-TBMonitorResponse -Response $response
        }
        else {
            $uri = '{0}/configurationMonitors' -f $baseUri
            Write-TBLog -Message 'Listing all monitors'
            $items = Invoke-TBGraphPagedRequest -Uri $uri

            foreach ($item in $items) {
                ConvertFrom-TBMonitorResponse -Response $item
            }
        }
    }
}
