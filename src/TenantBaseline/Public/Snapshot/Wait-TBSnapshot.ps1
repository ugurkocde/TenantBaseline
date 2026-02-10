function Wait-TBSnapshot {
    <#
    .SYNOPSIS
        Waits for a snapshot job to complete.
    .DESCRIPTION
        Polls the snapshot job status until it reaches a terminal state
        (succeeded, failed, or partiallySuccessful).
    .PARAMETER SnapshotId
        The ID of the snapshot to wait for.
    .PARAMETER TimeoutSeconds
        Maximum time to wait in seconds. Defaults to 600 (10 minutes).
    .PARAMETER PollingIntervalSeconds
        How often to check status in seconds. Defaults to 10.
    .EXAMPLE
        New-TBSnapshot | Wait-TBSnapshot
    .EXAMPLE
        Wait-TBSnapshot -SnapshotId '00000000-...' -TimeoutSeconds 300
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$SnapshotId,

        [Parameter()]
        [int]$TimeoutSeconds = 600,

        [Parameter()]
        [int]$PollingIntervalSeconds = 10
    )

    process {
        $uri = '{0}/configurationSnapshotJobs/{1}' -f (Get-TBApiBaseUri), $SnapshotId

        Write-TBLog -Message ('Waiting for snapshot {0} to complete (timeout: {1}s)' -f $SnapshotId, $TimeoutSeconds)

        $response = Wait-TBAsyncJob -Uri $uri `
            -TimeoutSeconds $TimeoutSeconds `
            -PollingIntervalSeconds $PollingIntervalSeconds `
            -TerminalStatuses @('succeeded', 'failed', 'partiallySuccessful')

        return ConvertFrom-TBSnapshotResponse -Response $response
    }
}
