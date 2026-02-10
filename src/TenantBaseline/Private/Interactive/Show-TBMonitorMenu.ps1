function Invoke-TBMonitorAction {
    <#
    .SYNOPSIS
        Executes a single monitor management action by index.
    .DESCRIPTION
        Contains the action logic extracted from Show-TBMonitorMenu's switch block.
        Called by both the classic submenu loop and the accordion direct-action path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ActionIndex
    )

    switch ($ActionIndex) {
        0 { # Create new monitor
            Write-Host ''
            Write-Host '  -- Create New Monitor --' -ForegroundColor Cyan

            $displayName = Read-TBUserInput -Prompt 'Monitor display name' -Mandatory `
                -MinLength 8 -MaxLength 32 `
                -Pattern '^[a-zA-Z0-9 ]{8,32}$' `
                -PatternMessage 'Must be 8-32 characters, alphanumeric and spaces only.'

            if (-not $displayName) { return }

            $description = Read-TBUserInput -Prompt 'Description (optional)'

            Write-Host ''
            Write-Host '  Select resource types for the baseline:' -ForegroundColor Cyan

            $resourceTypes = Select-TBResourceType
            if (-not $resourceTypes) {
                Write-Host '  No resource types selected. Cancelled.' -ForegroundColor Yellow
                Read-Host -Prompt '  Press Enter to continue'
                return
            }

            $confirmed = Read-TBUserInput -Prompt ('Create monitor "{0}" with {1} resource type(s)?' -f $displayName, $resourceTypes.Count) -Confirm
            if (-not $confirmed) { return }

            try {
                $params = @{
                    DisplayName = $displayName
                    Confirm     = $false
                }
                if ($description) {
                    $params['Description'] = $description
                }

                # Build simple baseline resources from type names
                $resources = foreach ($rt in $resourceTypes) {
                    [PSCustomObject]@{
                        resourceType = $rt
                        displayName  = $rt
                        properties   = @{}
                    }
                }
                $params['Resources'] = $resources

                $result = New-TBMonitor @params
                Write-Host ''
                Write-Host ('  Monitor created: {0}' -f $result.Id) -ForegroundColor Green
                Write-Host ('  Display Name: {0}' -f $result.DisplayName) -ForegroundColor White
                Write-Host ('  Status: {0}' -f $result.Status) -ForegroundColor White
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        1 { # List monitors
            Write-Host ''
            Write-Host '  -- Monitors --' -ForegroundColor Cyan
            Write-Host ''

            try {
                $monitors = @(Get-TBMonitor)
                if ($monitors.Count -eq 0) {
                    Write-Host '  No monitors found.' -ForegroundColor Yellow
                }
                else {
                    $monitors | Format-Table -Property @(
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
        2 { # View monitor details
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

                $monitor = Get-TBMonitor -MonitorId $monitors[$selected].Id
                Write-Host ''
                Write-Host '  -- Monitor Details --' -ForegroundColor Cyan
                Write-Host ('  ID:           {0}' -f $monitor.Id) -ForegroundColor White
                Write-Host ('  Display Name: {0}' -f $monitor.DisplayName) -ForegroundColor White
                Write-Host ('  Description:  {0}' -f $monitor.Description) -ForegroundColor White
                Write-Host ('  Status:       {0}' -f $monitor.Status) -ForegroundColor White
                Write-Host ('  Created:      {0}' -f $monitor.CreatedDateTime) -ForegroundColor White
                Write-Host ('  Modified:     {0}' -f $monitor.LastModifiedDateTime) -ForegroundColor White
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        3 { # Update monitor
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

                $selected = Show-TBMenu -Title 'Select Monitor to Update' -Options $monitorOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $monitorId = $monitors[$selected].Id

                Write-Host ''
                Write-Host '  Leave blank to keep current value.' -ForegroundColor DarkGray

                $newName = Read-TBUserInput -Prompt 'New display name'
                $newDesc = Read-TBUserInput -Prompt 'New description'

                $statusOptions = @('active', 'inactive', 'Keep current')
                $statusChoice = Show-TBMenu -Title 'New Status' -Options $statusOptions -IncludeBack
                if ($statusChoice -eq 'Back') { return }

                $updateParams = @{
                    MonitorId = $monitorId
                    Confirm   = $false
                }

                if ($newName) { $updateParams['DisplayName'] = $newName }
                if ($newDesc) { $updateParams['Description'] = $newDesc }
                if ($statusChoice -ne 2) { $updateParams['Status'] = $statusOptions[$statusChoice] }

                if ($updateParams.Count -le 2) {
                    Write-Host '  No changes specified.' -ForegroundColor Yellow
                }
                else {
                    Set-TBMonitor @updateParams
                    Write-Host '  Monitor updated.' -ForegroundColor Green
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        4 { # Delete monitor
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

                $selected = Show-TBMenu -Title 'Select Monitor to Delete' -Options $monitorOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $monitor = $monitors[$selected]
                $confirmed = Read-TBUserInput -Prompt ('Delete monitor "{0}"? This cannot be undone' -f $monitor.DisplayName) -Confirm
                if ($confirmed) {
                    Remove-TBMonitor -MonitorId $monitor.Id -Confirm:$false
                    Write-Host '  Monitor deleted.' -ForegroundColor Green
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
        5 { # View monitor results
            try {
                $monitors = @(Get-TBMonitor)
                if ($monitors.Count -eq 0) {
                    Write-Host ''
                    Write-Host '  No monitors found.' -ForegroundColor Yellow
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                $resultOptions = @('All monitors') + @(foreach ($m in $monitors) {
                    '{0} - {1}' -f $m.DisplayName, $m.Id
                })

                $selected = Show-TBMenu -Title 'View Results For' -Options $resultOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $resultParams = @{}
                if ($selected -gt 0) {
                    $resultParams['MonitorId'] = $monitors[$selected - 1].Id
                }

                $results = @(Get-TBMonitorResult @resultParams)
                Write-Host ''
                if ($results.Count -eq 0) {
                    Write-Host '  No results found.' -ForegroundColor Yellow
                }
                else {
                    $results | Format-Table -Property @(
                        @{ Label = 'Monitor ID'; Expression = { $_.MonitorId } }
                        @{ Label = 'Run Status'; Expression = { $_.RunStatus } }
                        @{ Label = 'Drifts'; Expression = { $_.DriftsCount } }
                        @{ Label = 'Started'; Expression = { $_.RunInitiationDateTime } }
                        @{ Label = 'Completed'; Expression = { $_.RunCompletionDateTime } }
                    ) -AutoSize | Out-Host
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
    }
}

function Show-TBMonitorMenu {
    <#
    .SYNOPSIS
        Displays the monitor management submenu.
    .DESCRIPTION
        Interactive menu for creating, listing, viewing, updating, and deleting
        configuration monitors, as well as viewing monitor results.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$DirectAction = -1
    )

    if ($DirectAction -ge 0) {
        Invoke-TBMonitorAction -ActionIndex $DirectAction
        return
    }

    while ($true) {
        Clear-Host
        Write-TBMenuHeader -Subtitle 'Monitor Management'

        $options = @(
            'Create new monitor'
            'List monitors'
            'View monitor details'
            'Update monitor'
            'Delete monitor'
            'View monitor results'
        )

        $choice = Show-TBMenu -Title 'Monitor Management' -Options $options -IncludeBack
        if ($choice -eq 'Back') { return }

        Invoke-TBMonitorAction -ActionIndex $choice
    }
}
