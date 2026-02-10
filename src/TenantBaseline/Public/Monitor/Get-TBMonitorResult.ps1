function Get-TBMonitorResult {
    <#
    .SYNOPSIS
        Gets monitoring results for configuration monitors.
    .DESCRIPTION
        Retrieves the run results and errors from UTCM configuration monitoring.
        Can filter by monitor ID.
    .PARAMETER MonitorId
        Optional monitor ID to filter results.
    .PARAMETER Top
        Maximum number of results to return.
    .EXAMPLE
        Get-TBMonitorResult
    .EXAMPLE
        Get-TBMonitorResult -MonitorId '00000000-...'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$MonitorId,

        [Parameter()]
        [int]$Top
    )

    process {
        $baseUri = Get-TBApiBaseUri
        $uri = '{0}/configurationMonitoringResults' -f $baseUri

        $queryParams = [System.Collections.ArrayList]::new()

        if ($MonitorId) {
            $null = $queryParams.Add("`$filter=monitorId eq '$MonitorId'")
        }

        if ($Top -gt 0) {
            $null = $queryParams.Add("`$top=$Top")
        }

        if ($queryParams.Count -gt 0) {
            $uri = '{0}?{1}' -f $uri, ($queryParams -join '&')
        }

        Write-TBLog -Message ('Getting monitor results: {0}' -f $uri)
        $items = Invoke-TBGraphPagedRequest -Uri $uri

        foreach ($item in $items) {
            if ($item -is [hashtable]) {
                $obj = [PSCustomObject]$item
            }
            else {
                $obj = $item
            }

            [PSCustomObject]@{
                PSTypeName            = 'TenantBaseline.MonitorResult'
                Id                    = if ($obj.PSObject.Properties['id']) { $obj.id } else { $null }
                MonitorId             = if ($obj.PSObject.Properties['monitorId']) { $obj.monitorId } else { $null }
                TenantId              = if ($obj.PSObject.Properties['tenantId']) { $obj.tenantId } else { $null }
                RunStatus             = if ($obj.PSObject.Properties['runStatus']) { $obj.runStatus } else { $null }
                RunInitiationDateTime = if ($obj.PSObject.Properties['runInitiationDateTime']) { $obj.runInitiationDateTime } else { $null }
                RunCompletionDateTime = if ($obj.PSObject.Properties['runCompletionDateTime']) { $obj.runCompletionDateTime } else { $null }
                DriftsCount           = if ($obj.PSObject.Properties['driftsCount']) { $obj.driftsCount } else { 0 }
                ErrorDetails          = if ($obj.PSObject.Properties['errorDetails']) { $obj.errorDetails } else { @() }
                RawResponse           = $item
            }
        }
    }
}
