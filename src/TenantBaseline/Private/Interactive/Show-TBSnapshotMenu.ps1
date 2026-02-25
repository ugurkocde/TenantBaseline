function Wait-TBSnapshotInteractive {
    <#
    .SYNOPSIS
        Polls a snapshot job with a smooth progress display.
    .DESCRIPTION
        Decouples the display refresh rate (250ms) from the API poll interval (10s)
        so the spinner and elapsed timer update smoothly while waiting.
    .PARAMETER SnapshotId
        The ID of the snapshot job to poll.
    .PARAMETER ResourceCount
        Number of resource types in the snapshot (shown in progress text).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SnapshotId,

        [Parameter(Mandatory = $true)]
        [int]$ResourceCount
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $spinIdx = 0
    $snapshot = Get-TBSnapshot -SnapshotId $SnapshotId
    $pollIntervalMs = 10000
    $displayIntervalMs = 250
    $lastPollTime = [DateTime]::UtcNow

    while ($snapshot.Status -eq 'notStarted' -or $snapshot.Status -eq 'running') {
        Write-TBSnapshotProgress -Status $snapshot.Status -ResourceCount $ResourceCount `
            -Stopwatch $sw -SpinIndex $spinIdx
        $spinIdx++
        Start-Sleep -Milliseconds $displayIntervalMs

        $msSincePoll = ([DateTime]::UtcNow - $lastPollTime).TotalMilliseconds
        if ($msSincePoll -ge $pollIntervalMs) {
            $snapshot = Get-TBSnapshot -SnapshotId $SnapshotId
            $lastPollTime = [DateTime]::UtcNow
        }
    }

    Write-TBProgressComplete -Stopwatch $sw
    return $snapshot
}

function Invoke-TBSnapshotAction {
    <#
    .SYNOPSIS
        Executes a single snapshot management action by index.
    .DESCRIPTION
        Contains the action logic extracted from Show-TBSnapshotMenu's switch block.
        Called by both the classic submenu loop and the accordion direct-action path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ActionIndex
    )

    switch ($ActionIndex) {
        0 { # Create snapshot - pick resource types
            Write-Host ''
            Write-Host '  -- Create Snapshot (Selected Resource Types) --' -ForegroundColor Cyan

            $resourceTypes = Select-TBResourceType
            if (-not $resourceTypes) {
                Write-Host '  No resource types selected. Cancelled.' -ForegroundColor Yellow
                Read-Host -Prompt '  Press Enter to continue'
                return
            }

            $displayName = Read-TBUserInput -Prompt 'Snapshot display name' -Mandatory `
                -MinLength 8 -MaxLength 32 `
                -Pattern '^[a-zA-Z0-9 ]{8,32}$' `
                -PatternMessage 'Must be 8-32 characters, alphanumeric and spaces only.'

            if (-not $displayName) { return }

            $description = Read-TBUserInput -Prompt 'Description (optional)'

            $confirmed = Read-TBUserInput -Prompt ('Create snapshot "{0}" with {1} resource type(s)?' -f $displayName, $resourceTypes.Count) -Confirm
            if (-not $confirmed) { return }

            try {
                $params = @{
                    DisplayName = $displayName
                    Resources   = $resourceTypes
                    Confirm     = $false
                }
                if ($description) {
                    $params['Description'] = $description
                }

                $result = New-TBSnapshot @params
                Write-Host ''
                Write-Host ('  Snapshot created: {0}' -f $result.Id) -ForegroundColor Green
                Write-Host ('  Status: {0}' -f $result.Status) -ForegroundColor White

                $waitForIt = Read-TBUserInput -Prompt 'Wait for completion?' -Confirm
                if ($waitForIt) {
                    $snapshot = Wait-TBSnapshotInteractive -SnapshotId $result.Id -ResourceCount $resourceTypes.Count
                    Write-Host ('  Final status: {0}' -f $snapshot.Status) -ForegroundColor White
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        1 { # Create snapshot - entire workload
            Write-Host ''
            Write-Host '  -- Create Snapshot (Entire Workload) --' -ForegroundColor Cyan

            $registry = Get-TBResourceTypeRegistry
            $workloadNames = @($registry.Keys | Sort-Object)
            $workloadOptions = foreach ($name in $workloadNames) {
                $count = $registry[$name].ResourceTypes.Count
                '{0} ({1} resource types)' -f $name, $count
            }

            $wChoice = Show-TBMenu -Title 'Select Workload' -Options $workloadOptions -IncludeBack
            if ($wChoice -eq 'Back') { return }

            $workloadName = $workloadNames[$wChoice]
            $resourceTypes = @($registry[$workloadName].ResourceTypes | ForEach-Object { $_.Name })

            Write-Host ''
            Write-Host ('  {0} - {1} resource types' -f $workloadName, $resourceTypes.Count) -ForegroundColor Green

            $displayName = Read-TBUserInput -Prompt 'Snapshot display name' -Mandatory `
                -MinLength 8 -MaxLength 32 `
                -Pattern '^[a-zA-Z0-9 ]{8,32}$' `
                -PatternMessage 'Must be 8-32 characters, alphanumeric and spaces only.'

            if (-not $displayName) { return }

            $description = Read-TBUserInput -Prompt 'Description (optional)'

            $confirmed = Read-TBUserInput -Prompt ('Create snapshot "{0}" with {1} resource type(s)?' -f $displayName, $resourceTypes.Count) -Confirm
            if (-not $confirmed) { return }

            try {
                $params = @{
                    DisplayName = $displayName
                    Resources   = $resourceTypes
                    Confirm     = $false
                }
                if ($description) {
                    $params['Description'] = $description
                }

                $result = New-TBSnapshot @params
                Write-Host ''
                Write-Host ('  Snapshot created: {0}' -f $result.Id) -ForegroundColor Green
                Write-Host ('  Status: {0}' -f $result.Status) -ForegroundColor White

                $waitForIt = Read-TBUserInput -Prompt 'Wait for completion?' -Confirm
                if ($waitForIt) {
                    $snapshot = Wait-TBSnapshotInteractive -SnapshotId $result.Id -ResourceCount $resourceTypes.Count
                    Write-Host ('  Final status: {0}' -f $snapshot.Status) -ForegroundColor White
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        2 { # Create snapshot - all workloads
            Write-Host ''
            Write-Host '  -- Create Snapshot (All Workloads) --' -ForegroundColor Cyan

            $registry = Get-TBResourceTypeRegistry
            $allTypes = [System.Collections.ArrayList]::new()
            foreach ($workloadName in ($registry.Keys | Sort-Object)) {
                foreach ($rt in $registry[$workloadName].ResourceTypes) {
                    $null = $allTypes.Add($rt.Name)
                }
            }

            Write-Host ('  All workloads - {0} resource types total' -f $allTypes.Count) -ForegroundColor Green

            $displayName = Read-TBUserInput -Prompt 'Snapshot display name' -Mandatory `
                -MinLength 8 -MaxLength 32 `
                -Pattern '^[a-zA-Z0-9 ]{8,32}$' `
                -PatternMessage 'Must be 8-32 characters, alphanumeric and spaces only.'

            if (-not $displayName) { return }

            $description = Read-TBUserInput -Prompt 'Description (optional)'

            $confirmed = Read-TBUserInput -Prompt ('Create snapshot "{0}" with {1} resource type(s)?' -f $displayName, $allTypes.Count) -Confirm
            if (-not $confirmed) { return }

            try {
                $params = @{
                    DisplayName = $displayName
                    Resources   = @($allTypes)
                    Confirm     = $false
                }
                if ($description) {
                    $params['Description'] = $description
                }

                $result = New-TBSnapshot @params
                Write-Host ''
                Write-Host ('  Snapshot created: {0}' -f $result.Id) -ForegroundColor Green
                Write-Host ('  Status: {0}' -f $result.Status) -ForegroundColor White

                $waitForIt = Read-TBUserInput -Prompt 'Wait for completion?' -Confirm
                if ($waitForIt) {
                    $snapshot = Wait-TBSnapshotInteractive -SnapshotId $result.Id -ResourceCount $allTypes.Count
                    Write-Host ('  Final status: {0}' -f $snapshot.Status) -ForegroundColor White
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        3 { # List snapshot jobs
            Write-Host ''
            Write-Host '  -- Snapshot Jobs --' -ForegroundColor Cyan
            Write-Host ''

            try {
                $snapshots = @(Get-TBSnapshot)
                if ($snapshots.Count -eq 0) {
                    Write-Host '  No snapshots found.' -ForegroundColor Yellow
                }
                else {
                    $snapshots | Format-Table -Property @(
                        @{ Label = 'ID'; Expression = { $_.Id } }
                        @{ Label = 'Display Name'; Expression = { $_.DisplayName } }
                        @{ Label = 'Status'; Expression = { $_.Status } }
                        @{ Label = 'Created'; Expression = { $_.CreatedDateTime } }
                    ) -AutoSize | Out-Host
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        4 { # View snapshot details
            try {
                $snapshots = @(Get-TBSnapshot)
                if ($snapshots.Count -eq 0) {
                    Write-Host ''
                    Write-Host '  No snapshots found.' -ForegroundColor Yellow
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                $snapshotOptions = foreach ($s in $snapshots) {
                    '{0} - {1} ({2})' -f $s.DisplayName, $s.Id, $s.Status
                }

                $selected = Show-TBMenu -Title 'Select Snapshot' -Options $snapshotOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $snapshot = Get-TBSnapshot -SnapshotId $snapshots[$selected].Id
                Write-Host ''
                Write-Host '  -- Snapshot Details --' -ForegroundColor Cyan
                Write-Host ('  ID:           {0}' -f $snapshot.Id) -ForegroundColor White
                Write-Host ('  Display Name: {0}' -f $snapshot.DisplayName) -ForegroundColor White
                Write-Host ('  Status:       {0}' -f $snapshot.Status) -ForegroundColor White
                Write-Host ('  Created:      {0}' -f $snapshot.CreatedDateTime) -ForegroundColor White
                Write-Host ('  Completed:    {0}' -f $snapshot.CompletedDateTime) -ForegroundColor White

                if ($snapshot.Resources) {
                    Write-Host ('  Resources:    {0}' -f (@($snapshot.Resources) -join ', ')) -ForegroundColor White
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        5 { # Export snapshot
            try {
                $snapshots = @(Get-TBSnapshot)
                if ($snapshots.Count -eq 0) {
                    Write-Host ''
                    Write-Host '  No snapshots found.' -ForegroundColor Yellow
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                $snapshotOptions = foreach ($s in $snapshots) {
                    '{0} - {1} ({2})' -f $s.DisplayName, $s.Id, $s.Status
                }

                $selected = Show-TBMenu -Title 'Select Snapshot to Export' -Options $snapshotOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $outputPath = Read-TBUserInput -Prompt 'Output file path (leave blank for default)'

                $exportParams = @{
                    SnapshotId = $snapshots[$selected].Id
                }
                if ($outputPath) {
                    $exportParams['OutputPath'] = $outputPath
                }

                $result = Export-TBSnapshot @exportParams
                Write-Host ''
                Write-Host ('  Snapshot exported to: {0}' -f $result.OutputPath) -ForegroundColor Green
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        6 { # Delete snapshot
            try {
                $snapshots = @(Get-TBSnapshot)
                if ($snapshots.Count -eq 0) {
                    Write-Host ''
                    Write-Host '  No snapshots found.' -ForegroundColor Yellow
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                $snapshotOptions = foreach ($s in $snapshots) {
                    '{0} - {1} ({2})' -f $s.DisplayName, $s.Id, $s.Status
                }

                $selected = Show-TBMenu -Title 'Select Snapshot to Delete' -Options $snapshotOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $snapshot = $snapshots[$selected]
                $confirmed = Read-TBUserInput -Prompt ('Delete snapshot "{0}"? This cannot be undone' -f $snapshot.DisplayName) -Confirm
                if ($confirmed) {
                    Remove-TBSnapshot -SnapshotId $snapshot.Id -Confirm:$false
                    Write-Host '  Snapshot deleted.' -ForegroundColor Green
                }
                else {
                    Write-Host '  Cancelled.' -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        7 { # Create from monitor baseline
            Write-Host ''
            Write-Host '  -- Create Snapshot from Monitor Baseline --' -ForegroundColor Cyan

            try {
                $monitors = @(Get-TBMonitor)
                if ($monitors.Count -eq 0) {
                    Write-Host '  No monitors found.' -ForegroundColor Yellow
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                $monitorOptions = foreach ($m in $monitors) {
                    '{0} - {1}' -f $m.DisplayName, $m.Id
                }

                $selected = Show-TBMenu -Title 'Select Monitor' -Options $monitorOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $monitor = $monitors[$selected]

                $displayName = Read-TBUserInput -Prompt 'Snapshot display name (leave blank for default)'

                $snapshotParams = @{
                    MonitorId = $monitor.Id
                    Confirm   = $false
                }
                if ($displayName) {
                    $snapshotParams['DisplayName'] = $displayName
                }

                $result = New-TBBaselineSnapshot @snapshotParams
                if ($result) {
                    Write-Host ''
                    Write-Host ('  Snapshot created: {0}' -f $result.Id) -ForegroundColor Green
                    Write-Host ('  Status: {0}' -f $result.Status) -ForegroundColor White

                    $waitForIt = Read-TBUserInput -Prompt 'Wait for completion?' -Confirm
                    if ($waitForIt) {
                        $baseline = Get-TBBaseline -MonitorId $monitor.Id
                        $resourceCount = @($baseline.Resources).Count
                        $snapshot = Wait-TBSnapshotInteractive -SnapshotId $result.Id -ResourceCount $resourceCount
                        Write-Host ('  Final status: {0}' -f $snapshot.Status) -ForegroundColor White
                    }
                }
                else {
                    Write-Host '  No snapshot created (baseline may be empty).' -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        8 { # Compare snapshots
            Write-Host ''
            Write-Host '  -- Compare Snapshots --' -ForegroundColor Cyan

            try {
                $snapshots = @(Get-TBSnapshot)
                $completedSnapshots = @($snapshots | Where-Object { $_.Status -eq 'succeeded' -or $_.Status -eq 'partiallySuccessful' })

                if ($completedSnapshots.Count -lt 2) {
                    Write-Host '  Need at least 2 completed snapshots to compare.' -ForegroundColor Yellow
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                $snapshotOptions = foreach ($s in $completedSnapshots) {
                    '{0} - {1} ({2})' -f $s.DisplayName, $s.Id, $s.Status
                }

                Write-Host ''
                $refSelected = Show-TBMenu -Title 'Select Reference Snapshot' -Options $snapshotOptions -IncludeBack
                if ($refSelected -eq 'Back') { return }

                $diffSelected = Show-TBMenu -Title 'Select Difference Snapshot' -Options $snapshotOptions -IncludeBack
                if ($diffSelected -eq 'Back') { return }

                if ($refSelected -eq $diffSelected) {
                    Write-Host '  Cannot compare a snapshot with itself.' -ForegroundColor Yellow
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                Write-Host ''
                Write-Host '  Comparing snapshots...' -ForegroundColor Cyan

                $diffs = Compare-TBSnapshot `
                    -ReferenceSnapshotId $completedSnapshots[$refSelected].Id `
                    -DifferenceSnapshotId $completedSnapshots[$diffSelected].Id

                if ($diffs.Count -eq 0) {
                    Write-Host '  No differences found.' -ForegroundColor Green
                }
                else {
                    Write-Host ''
                    Write-Host ('  Found {0} difference(s):' -f $diffs.Count) -ForegroundColor Yellow
                    $diffs | Format-Table -Property ResourceType, ResourceName, Property, DiffType, ReferenceValue, DifferenceValue -AutoSize | Out-Host
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
    }
}

function Show-TBSnapshotMenu {
    <#
    .SYNOPSIS
        Displays the snapshot management submenu.
    .DESCRIPTION
        Interactive menu for creating, listing, viewing, exporting, and deleting
        configuration snapshots.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$DirectAction = -1
    )

    if ($DirectAction -ge 0) {
        Invoke-TBSnapshotAction -ActionIndex $DirectAction
        return
    }

    while ($true) {
        Clear-Host
        Write-TBMenuHeader -Subtitle 'Snapshot Management'

        $options = @(
            'Create snapshot - pick resource types'
            'Create snapshot - entire workload'
            'Create snapshot - all workloads'
            'List snapshot jobs'
            'View snapshot details'
            'Export snapshot'
            'Delete snapshot'
            'Create from monitor baseline'
            'Compare snapshots'
        )

        $choice = Show-TBMenu -Title 'Snapshot Management' -Options $options -IncludeBack
        if ($choice -eq 'Back') { return }

        Invoke-TBSnapshotAction -ActionIndex $choice
    }
}
