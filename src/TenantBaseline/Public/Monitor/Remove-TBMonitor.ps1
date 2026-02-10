function Remove-TBMonitor {
    <#
    .SYNOPSIS
        Deletes a configuration monitor.
    .DESCRIPTION
        Removes a UTCM configuration monitor by ID.
    .PARAMETER MonitorId
        The ID of the monitor to delete.
    .EXAMPLE
        Remove-TBMonitor -MonitorId '00000000-0000-0000-0000-000000000000'
    .EXAMPLE
        Get-TBMonitor | Where-Object Status -eq 'disabled' | Remove-TBMonitor
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$MonitorId
    )

    process {
        $uri = '{0}/configurationMonitors/{1}' -f (Get-TBApiBaseUri), $MonitorId

        if ($PSCmdlet.ShouldProcess($MonitorId, 'Delete configuration monitor')) {
            Write-TBLog -Message ('Deleting monitor: {0}' -f $MonitorId)
            $null = Invoke-TBGraphRequest -Uri $uri -Method 'DELETE'
            Write-TBLog -Message ('Monitor {0} deleted' -f $MonitorId)
        }
    }
}
