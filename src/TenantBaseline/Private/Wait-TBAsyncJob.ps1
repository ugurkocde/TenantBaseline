function Wait-TBAsyncJob {
    <#
    .SYNOPSIS
        Polls an async job until it reaches a terminal state.
    .DESCRIPTION
        Repeatedly checks the status of an async job (snapshot, etc.) until
        it completes, fails, or the timeout is reached.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter()]
        [int]$TimeoutSeconds = 600,

        [Parameter()]
        [int]$PollingIntervalSeconds = 10,

        [Parameter()]
        [string[]]$TerminalStatuses = @('completed', 'succeeded', 'failed', 'cancelled')
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($stopwatch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $response = Invoke-TBGraphRequest -Uri $Uri -Method 'GET'

        $status = $null
        if ($response.PSObject.Properties['status']) {
            $status = $response.status
        }
        elseif ($response -is [hashtable] -and $response.ContainsKey('status')) {
            $status = $response['status']
        }

        Write-TBLog -Message ('Job status: {0}' -f $status)

        if ($status) {
            $statusLower = $status.ToLower()
            foreach ($terminal in $TerminalStatuses) {
                if ($statusLower -eq $terminal.ToLower()) {
                    $stopwatch.Stop()
                    return $response
                }
            }
        }

        Start-Sleep -Seconds $PollingIntervalSeconds
    }

    $stopwatch.Stop()
    throw ('Async job did not complete within {0} seconds. Last status: {1}' -f $TimeoutSeconds, $status)
}
