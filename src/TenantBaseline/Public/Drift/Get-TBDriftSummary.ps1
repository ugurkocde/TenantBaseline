function Get-TBDriftSummary {
    <#
    .SYNOPSIS
        Provides an aggregated summary of detected configuration drifts.
    .DESCRIPTION
        Retrieves all drifts and groups them by resource type, monitor, and status
        to provide an overview of the drift landscape.
    .PARAMETER MonitorId
        Optional monitor ID to scope the summary.
    .EXAMPLE
        Get-TBDriftSummary
    .EXAMPLE
        Get-TBDriftSummary -MonitorId '00000000-...'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$MonitorId
    )

    $driftParams = @{}
    if ($MonitorId) {
        $driftParams['MonitorId'] = $MonitorId
    }

    $drifts = @(Get-TBDrift @driftParams)

    $byResourceType = @{}
    $byMonitor = @{}
    $byStatus = @{}
    $totalDriftedProperties = 0

    foreach ($drift in $drifts) {
        # Group by resource type
        $rt = if ($drift.ResourceType) { $drift.ResourceType } else { 'Unknown' }
        if (-not $byResourceType.ContainsKey($rt)) { $byResourceType[$rt] = 0 }
        $byResourceType[$rt]++

        # Group by monitor
        $mid = if ($drift.MonitorId) { $drift.MonitorId } else { 'Unknown' }
        if (-not $byMonitor.ContainsKey($mid)) { $byMonitor[$mid] = 0 }
        $byMonitor[$mid]++

        # Group by status (active/fixed)
        $st = if ($drift.Status) { $drift.Status } else { 'Unknown' }
        if (-not $byStatus.ContainsKey($st)) { $byStatus[$st] = 0 }
        $byStatus[$st]++

        # Count total drifted properties
        if ($drift.DriftedProperties) {
            $totalDriftedProperties += @($drift.DriftedProperties).Count
        }
    }

    [PSCustomObject]@{
        PSTypeName             = 'TenantBaseline.DriftSummary'
        TotalDrifts            = $drifts.Count
        TotalDriftedProperties = $totalDriftedProperties
        ByResourceType         = [PSCustomObject]$byResourceType
        ByMonitor              = [PSCustomObject]$byMonitor
        ByStatus               = [PSCustomObject]$byStatus
        GeneratedAt            = Get-Date
    }
}
