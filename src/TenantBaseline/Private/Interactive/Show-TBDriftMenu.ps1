function Invoke-TBDriftAction {
    <#
    .SYNOPSIS
        Executes a single drift detection action by index.
    .DESCRIPTION
        Contains the action logic extracted from Show-TBDriftMenu's switch block.
        Called by both the classic submenu loop and the accordion direct-action path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ActionIndex
    )

    switch ($ActionIndex) {
        0 { # View all drifts
            Write-Host ''
            Write-Host '  -- All Drifts --' -ForegroundColor Cyan
            Write-Host ''

            try {
                $drifts = @(Get-TBDrift)
                if ($drifts.Count -eq 0) {
                    Write-Host '  No drifts detected.' -ForegroundColor Green
                }
                else {
                    $drifts | Format-Table -Property @(
                        @{ Label = 'ID'; Expression = { $_.Id } }
                        @{ Label = 'Resource Type'; Expression = { $_.ResourceType } }
                        @{ Label = 'Resource'; Expression = { $_.BaselineResourceDisplayName } }
                        @{ Label = 'Status'; Expression = { $_.Status } }
                        @{ Label = 'Drifted Props'; Expression = { @($_.DriftedProperties).Count } }
                    ) -AutoSize | Out-Host
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        1 { # View drifts by monitor
            try {
                $monitors = @(Get-TBMonitor)
                if ($monitors.Count -eq 0) {
                    Write-Host ''
                    Write-Host '  No monitors found.' -ForegroundColor Yellow
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                $monitorOptions = foreach ($m in $monitors) {
                    '{0} - {1}' -f $m.DisplayName, $m.Id
                }

                $selected = Show-TBMenu -Title 'Select Monitor' -Options $monitorOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                Write-Host ''
                Write-Host ('  -- Drifts for {0} --' -f $monitors[$selected].DisplayName) -ForegroundColor Cyan
                Write-Host ''

                $drifts = @(Get-TBDrift -MonitorId $monitors[$selected].Id)
                if ($drifts.Count -eq 0) {
                    Write-Host '  No drifts detected for this monitor.' -ForegroundColor Green
                }
                else {
                    $drifts | Format-Table -Property @(
                        @{ Label = 'ID'; Expression = { $_.Id } }
                        @{ Label = 'Resource Type'; Expression = { $_.ResourceType } }
                        @{ Label = 'Resource'; Expression = { $_.BaselineResourceDisplayName } }
                        @{ Label = 'Status'; Expression = { $_.Status } }
                        @{ Label = 'Drifted Props'; Expression = { @($_.DriftedProperties).Count } }
                    ) -AutoSize | Out-Host
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        2 { # Drift summary
            Write-Host ''
            Write-Host '  -- Drift Summary --' -ForegroundColor Cyan
            Write-Host ''

            try {
                $summary = Get-TBDriftSummary
                Write-Host ('  Total Drifts:            {0}' -f $summary.TotalDrifts) -ForegroundColor White
                Write-Host ('  Total Drifted Properties: {0}' -f $summary.TotalDriftedProperties) -ForegroundColor White
                Write-Host ('  Generated At:            {0}' -f $summary.GeneratedAt) -ForegroundColor White

                Write-Host ''
                Write-Host '  By Status:' -ForegroundColor Cyan
                if ($summary.ByStatus.PSObject.Properties.Count -gt 0) {
                    foreach ($prop in $summary.ByStatus.PSObject.Properties) {
                        Write-Host ('    {0}: {1}' -f $prop.Name, $prop.Value) -ForegroundColor White
                    }
                }
                else {
                    Write-Host '    (none)' -ForegroundColor DarkGray
                }

                Write-Host ''
                Write-Host '  By Resource Type:' -ForegroundColor Cyan
                if ($summary.ByResourceType.PSObject.Properties.Count -gt 0) {
                    foreach ($prop in $summary.ByResourceType.PSObject.Properties) {
                        Write-Host ('    {0}: {1}' -f $prop.Name, $prop.Value) -ForegroundColor White
                    }
                }
                else {
                    Write-Host '    (none)' -ForegroundColor DarkGray
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        3 { # View drift details
            Write-Host ''
            Write-Host '  -- Drift Details --' -ForegroundColor Cyan
            Write-Host ''

            try {
                $drifts = @(Get-TBDrift)
                if ($drifts.Count -eq 0) {
                    Write-Host '  No drifts detected.' -ForegroundColor Green
                }
                else {
                    for ($i = 0; $i -lt $drifts.Count; $i++) {
                        $d = $drifts[$i]
                        $statusColor = 'Yellow'
                        if ($d.Status -ne 'active') { $statusColor = 'Green' }

                        $instance = ''
                        if ($d.ResourceInstanceIdentifier) {
                            if ($d.ResourceInstanceIdentifier -is [hashtable]) {
                                $instance = $d.ResourceInstanceIdentifier['Identity']
                            }
                            else {
                                $instance = $d.ResourceInstanceIdentifier.Identity
                            }
                        }

                        Write-Host ('  --- Drift {0} of {1} ---' -f ($i + 1), $drifts.Count) -ForegroundColor Cyan
                        Write-Host ('  Resource Type:  {0}' -f $d.ResourceType) -ForegroundColor White
                        Write-Host ('  Resource:       {0}' -f $d.BaselineResourceDisplayName) -ForegroundColor White
                        if ($instance) {
                            Write-Host ('  Instance:       {0}' -f $instance) -ForegroundColor White
                        }
                        Write-Host ('  Status:         {0}' -f $d.Status) -ForegroundColor $statusColor
                        Write-Host ('  First Detected: {0}' -f $d.FirstReportedDateTime) -ForegroundColor DarkGray
                        Write-Host ''

                        $props = @($d.DriftedProperties)
                        if ($props.Count -gt 0) {
                            Write-Host '  Property                        Current Value        Desired Value' -ForegroundColor DarkCyan
                            Write-Host '  --------                        -------------        -------------' -ForegroundColor DarkGray

                            foreach ($prop in $props) {
                                if ($prop -is [hashtable]) {
                                    $pName = $prop['propertyName']
                                    $pCurrent = "$($prop['currentValue'])"
                                    $pDesired = "$($prop['desiredValue'])"
                                }
                                else {
                                    $pName = $prop.propertyName
                                    $pCurrent = "$($prop.currentValue)"
                                    $pDesired = "$($prop.desiredValue)"
                                }

                                Write-Host ('  {0}  {1}  {2}' -f $pName.PadRight(32), $pCurrent.PadRight(19), $pDesired) -ForegroundColor White
                            }
                        }
                        else {
                            Write-Host '  (no drifted properties reported)' -ForegroundColor DarkGray
                        }

                        Write-Host ''
                    }
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
    }
}

function Show-TBDriftMenu {
    <#
    .SYNOPSIS
        Displays the drift detection submenu.
    .DESCRIPTION
        Interactive menu for viewing drifts, drift summaries, and generating
        drift reports.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$DirectAction = -1
    )

    if ($DirectAction -ge 0) {
        Invoke-TBDriftAction -ActionIndex $DirectAction
        return
    }

    while ($true) {
        Clear-Host
        Write-TBMenuHeader -Subtitle 'Drift Detection'

        $options = @(
            'View all drifts'
            'View drifts by monitor'
            'Drift summary'
            'View drift details'
        )

        $choice = Show-TBMenu -Title 'Drift Detection' -Options $options -IncludeBack
        if ($choice -eq 'Back') { return }

        Invoke-TBDriftAction -ActionIndex $choice
    }
}
