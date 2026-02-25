function Get-TBQuotaStatus {
    <#
    .SYNOPSIS
        Returns current UTCM quota usage and limits.
    .DESCRIPTION
        Queries the current number of monitors and snapshot jobs, then compares
        against the documented UTCM limits (30 monitors, 800 monitored
        resource-instances per day, 12 snapshot jobs).
    .EXAMPLE
        Get-TBQuotaStatus
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $monitors = @(Get-TBMonitor)

    $totalBaselineResources = 0
    foreach ($monitor in $monitors) {
        try {
            $baseline = Get-TBBaseline -MonitorId $monitor.Id
            $totalBaselineResources += @($baseline.Resources).Count
        }
        catch {
            Write-TBLog -Message ('Could not load baseline for monitor {0}: {1}' -f $monitor.Id, $_.Exception.Message) -Level 'Warning'
        }
    }

    # UTCM runs 4 evaluation cycles per day
    $monitoredResourcesPerDay = $totalBaselineResources * 4

    $snapshots = @(Get-TBSnapshot)

    [PSCustomObject]@{
        PSTypeName                = 'TenantBaseline.QuotaStatus'
        MonitorCount              = $monitors.Count
        MonitorLimit              = 30
        TotalBaselineResources    = $totalBaselineResources
        MonitoredResourcesPerDay  = $monitoredResourcesPerDay
        ResourceDayLimit          = 800
        SnapshotJobCount          = $snapshots.Count
        SnapshotJobLimit          = 12
    }
}
