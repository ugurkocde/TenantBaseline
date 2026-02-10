function Get-TBBaseline {
    <#
    .SYNOPSIS
        Gets the baseline configuration from a monitor.
    .DESCRIPTION
        Retrieves the baseline (expected configuration) associated with
        a specific configuration monitor. The baseline contains the resources
        and their desired property values.
    .PARAMETER MonitorId
        The ID of the monitor to get the baseline from.
    .EXAMPLE
        Get-TBBaseline -MonitorId '00000000-...'
    .EXAMPLE
        Get-TBMonitor | Get-TBBaseline
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$MonitorId
    )

    process {
        $uri = '{0}/configurationMonitors/{1}/baseline' -f (Get-TBApiBaseUri), $MonitorId

        Write-TBLog -Message ('Getting baseline for monitor: {0}' -f $MonitorId)
        $response = Invoke-TBGraphRequest -Uri $uri -Method 'GET'

        if ($response -is [hashtable]) {
            $obj = [PSCustomObject]$response
        }
        else {
            $obj = $response
        }

        [PSCustomObject]@{
            PSTypeName  = 'TenantBaseline.Baseline'
            Id          = if ($obj.PSObject.Properties['id']) { $obj.id } else { $null }
            MonitorId   = $MonitorId
            DisplayName = if ($obj.PSObject.Properties['displayName']) { $obj.displayName } else { $null }
            Description = if ($obj.PSObject.Properties['description']) { $obj.description } else { $null }
            Parameters  = if ($obj.PSObject.Properties['parameters']) { $obj.parameters } else { @() }
            Resources   = if ($obj.PSObject.Properties['resources']) { $obj.resources } else { @() }
            RawResponse = $response
        }
    }
}
