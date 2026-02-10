function Write-TBProgressInline {
    <#
    .SYNOPSIS
        Displays a simple inline spinner for polling operations.
    .DESCRIPTION
        Updates a single line with spinner animation. Call repeatedly in a loop.
        Use Write-TBProgressComplete when done.
    .PARAMETER Activity
        Description of the activity.
    .PARAMETER Stopwatch
        A running Stopwatch instance for elapsed time display.
    .PARAMETER SpinIndex
        The current spin index (caller increments each call).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Stopwatch]$Stopwatch,

        [Parameter(Mandatory = $true)]
        [int]$SpinIndex
    )

    $spinChars = @('|', '/', '-', '\')
    $elapsed = $Stopwatch.Elapsed
    $timeStr = '{0:00}:{1:00}' -f [Math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
    $char = $spinChars[$SpinIndex % $spinChars.Count]
    $line = "`r  {0} {1}  [{2}]" -f $char, $Activity, $timeStr
    Write-Host $line -NoNewline -ForegroundColor Yellow
}

function Write-TBSnapshotProgress {
    <#
    .SYNOPSIS
        Displays a rich inline progress line for snapshot polling operations.
    .DESCRIPTION
        Shows spinner, status-aware activity text, resource count, and elapsed time.
        Designed to be called at a fast refresh rate (e.g. 250ms) while the API is
        polled less frequently.
    .PARAMETER Status
        Current snapshot status (notStarted or running).
    .PARAMETER ResourceCount
        Number of resource types in the snapshot.
    .PARAMETER Stopwatch
        A running Stopwatch instance for elapsed time display.
    .PARAMETER SpinIndex
        The current spin index (caller increments each call).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [int]$ResourceCount,

        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Stopwatch]$Stopwatch,

        [Parameter(Mandatory = $true)]
        [int]$SpinIndex
    )

    $spinChars = @('|', '/', '-', '\')
    $elapsed = $Stopwatch.Elapsed
    $timeStr = '{0:00}:{1:00}' -f [Math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
    $char = $spinChars[$SpinIndex % $spinChars.Count]

    if ($Status -eq 'running') {
        $activity = 'Capturing configuration'
    }
    else {
        $activity = 'Waiting to start'
    }

    $line = "`r  {0} {1} ({2} resource types)  [{3}]" -f $char, $activity, $ResourceCount, $timeStr
    Write-Host $line -NoNewline -ForegroundColor Yellow
}

function Write-TBProgressComplete {
    <#
    .SYNOPSIS
        Clears the inline spinner line and shows completion.
    .PARAMETER Stopwatch
        The stopwatch used during the progress display.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Stopwatch]$Stopwatch
    )

    $Stopwatch.Stop()
    $clearLine = "`r" + (' ' * 80) + "`r"
    Write-Host $clearLine -NoNewline

    $elapsed = $Stopwatch.Elapsed
    $timeStr = '{0:00}:{1:00}' -f [Math]::Floor($elapsed.TotalMinutes), $elapsed.Seconds
    Write-Host ('  Done. ({0})' -f $timeStr) -ForegroundColor Green
}
