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

            $resourceTypes = Select-TBResourceType -SingleWorkload
            if (-not $resourceTypes) {
                Write-Host '  No resource types selected. Cancelled.' -ForegroundColor Yellow
                Read-Host -Prompt '  Press Enter to continue'
                return
            }

            $confirmed = Read-TBUserInput -Prompt ('Create monitor "{0}" with {1} resource type(s)?' -f $displayName, $resourceTypes.Count) -Confirm
            if (-not $confirmed) { return }

            try {
                # Take an automatic snapshot to discover current tenant config
                Write-Host ''
                Write-Host '  Capturing current tenant configuration...' -ForegroundColor Cyan

                $discovery = New-TBSnapshotDiscovery -ResourceTypes $resourceTypes
                $snapshotProps = $discovery.Properties
                $unsupportedBySnapshot = $discovery.UnsupportedTypes

                if ($discovery.UnsupportedTypes.Count -gt 0) {
                    Write-Host ''
                    Write-Host ('  Note: {0} resource type(s) not supported by the snapshot API:' -f $discovery.UnsupportedTypes.Count) -ForegroundColor Yellow
                    foreach ($u in $discovery.UnsupportedTypes) {
                        Write-Host ('    - {0}' -f $u) -ForegroundColor Yellow
                    }
                    Write-Host '  These will use current tenant configuration as baseline.' -ForegroundColor Yellow
                }

                if (-not $discovery.Success) {
                    Write-Host '  Snapshot failed. Cannot resolve resource properties.' -ForegroundColor Yellow
                }

                # Build resources: use snapshot properties where available,
                # fall back to empty properties for snapshot-unsupported types
                $resources = @()
                $skippedTypes = @()
                foreach ($rt in $resourceTypes) {
                    $key = $rt.ToLower()
                    if ($snapshotProps.ContainsKey($key)) {
                        $resources += [PSCustomObject]@{
                            resourceType = $rt
                            displayName  = $rt
                            properties   = $snapshotProps[$key]
                        }
                    }
                    elseif ($key -in @($unsupportedBySnapshot | ForEach-Object { $_.ToLower() })) {
                        # Snapshot API doesn't support this type; use empty properties
                        # (the monitor API will use current tenant config as baseline)
                        $resources += [PSCustomObject]@{
                            resourceType = $rt
                            displayName  = $rt
                            properties   = @{}
                        }
                    }
                    else {
                        $skippedTypes += $rt
                    }
                }

                # Report types with no existing config in the snapshot
                if ($skippedTypes.Count -gt 0) {
                    Write-Host ''
                    Write-Host ('  Note: {0} resource type(s) have no existing configuration and were excluded:' -f $skippedTypes.Count) -ForegroundColor Yellow
                    foreach ($st in $skippedTypes) {
                        Write-Host ('    - {0}' -f $st) -ForegroundColor Yellow
                    }
                }

                # Abort if nothing left
                if ($resources.Count -eq 0) {
                    Write-Host ''
                    Write-Host '  No resource types could be resolved. Cannot create monitor.' -ForegroundColor Red
                    if ($discovery.SnapshotId) {
                        try { Remove-TBSnapshot -SnapshotId $discovery.SnapshotId -Confirm:$false } catch {}
                    }
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                # Re-confirm if types were filtered
                if ($skippedTypes.Count -gt 0) {
                    Write-Host ''
                    $reconfirmed = Read-TBUserInput -Prompt ('Create monitor with {0} resource type(s)?' -f $resources.Count) -Confirm
                    if (-not $reconfirmed) {
                        if ($discovery.SnapshotId) {
                            try { Remove-TBSnapshot -SnapshotId $discovery.SnapshotId -Confirm:$false } catch {}
                        }
                        return
                    }
                }

                $createParams = @{
                    DisplayName = $displayName
                    Resources   = $resources
                }
                if ($description) {
                    $createParams['Description'] = $description
                }

                $creation = Invoke-TBMonitorCreateWithRetry @createParams

                if ($creation.RejectedTypes.Count -gt 0) {
                    Write-Host ''
                    Write-Host ('  Note: {0} resource type(s) rejected by the monitor API:' -f $creation.RejectedTypes.Count) -ForegroundColor Yellow
                    foreach ($rj in $creation.RejectedTypes) {
                        Write-Host ('    - {0}' -f $rj) -ForegroundColor Yellow
                    }
                }

                if ($creation.Result) {
                    Write-Host ''
                    Write-Host ('  Monitor created: {0}' -f $creation.Result.Id) -ForegroundColor Green
                    Write-Host ('  Display Name: {0}' -f $creation.Result.DisplayName) -ForegroundColor White
                    Write-Host ('  Status: {0}' -f $creation.Result.Status) -ForegroundColor White
                }
                else {
                    Write-Host ''
                    Write-Host '  All resource types were rejected. Monitor was not created.' -ForegroundColor Red
                }

                # Best-effort cleanup of the temporary snapshot
                if ($discovery.SnapshotId) {
                    try { Remove-TBSnapshot -SnapshotId $discovery.SnapshotId -Confirm:$false } catch {}
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        1 { # Create from security catalog
            $catalog = Get-TBBaselineCatalog
            $resourceTypes = Select-TBCatalogEntry
            if (-not $resourceTypes) {
                Write-Host '  No categories selected. Cancelled.' -ForegroundColor Yellow
                Read-Host -Prompt '  Press Enter to continue'
                return
            }

            $displayName = Read-TBUserInput -Prompt 'Monitor display name' -Mandatory `
                -MinLength 8 -MaxLength 32 `
                -Pattern '^[a-zA-Z0-9 ]{8,32}$' `
                -PatternMessage 'Must be 8-32 characters, alphanumeric and spaces only.'

            if (-not $displayName) { return }

            $description = Read-TBUserInput -Prompt 'Description (optional)'

            $confirmed = Read-TBUserInput -Prompt ('Create monitor "{0}" with {1} resource type(s) from security catalog?' -f $displayName, $resourceTypes.Count) -Confirm
            if (-not $confirmed) { return }

            try {
                # Snapshot discovers required keys (like Id) that the catalog lacks
                Write-Host ''
                Write-Host '  Capturing current tenant configuration...' -ForegroundColor Cyan

                $discovery = New-TBSnapshotDiscovery -ResourceTypes $resourceTypes
                $snapshotProps = $discovery.Properties

                if ($discovery.UnsupportedTypes.Count -gt 0) {
                    Write-Host ''
                    Write-Host ('  Note: {0} resource type(s) not supported by the snapshot API:' -f $discovery.UnsupportedTypes.Count) -ForegroundColor Yellow
                    foreach ($u in $discovery.UnsupportedTypes) {
                        Write-Host ('    - {0}' -f $u) -ForegroundColor Yellow
                    }
                }

                if (-not $discovery.Success) {
                    Write-Host '  Snapshot failed. Cannot resolve resource properties.' -ForegroundColor Yellow
                }

                # Build catalog property lookup (keyed by lowercase resource type)
                $catalogProps = @{}
                foreach ($cat in $catalog.Categories) {
                    foreach ($br in $cat.BaselineResources) {
                        $key = $br.ResourceType.ToLower()
                        if (-not $catalogProps.ContainsKey($key)) {
                            $catalogProps[$key] = $br.Properties
                        }
                    }
                }

                # Build resources: snapshot base + catalog overlay (minus IsSingleInstance)
                $resources = @()
                $skippedTypes = @()
                foreach ($rt in $resourceTypes) {
                    $key = $rt.ToLower()
                    $baseProps = $null
                    $hasSnapshot = $snapshotProps.ContainsKey($key)
                    $isUnsupported = $key -in @($discovery.UnsupportedTypes | ForEach-Object { $_.ToLower() })

                    if ($hasSnapshot) {
                        # Start with snapshot properties as base
                        $baseProps = @{}
                        $snapObj = $snapshotProps[$key]
                        if ($snapObj -is [hashtable]) {
                            foreach ($k in $snapObj.Keys) { $baseProps[$k] = $snapObj[$k] }
                        }
                        else {
                            foreach ($p in $snapObj.PSObject.Properties) { $baseProps[$p.Name] = $p.Value }
                        }
                    }
                    elseif ($isUnsupported) {
                        # Snapshot API does not support this type; start with empty base
                        $baseProps = @{}
                    }
                    else {
                        # No snapshot data and not unsupported -- type has no config
                        $skippedTypes += $rt
                        continue
                    }

                    # Overlay catalog recommended values (minus IsSingleInstance)
                    if ($catalogProps.ContainsKey($key)) {
                        $catObj = $catalogProps[$key]
                        if ($catObj -is [hashtable]) {
                            foreach ($k in $catObj.Keys) {
                                if ($k -ne 'IsSingleInstance') { $baseProps[$k] = $catObj[$k] }
                            }
                        }
                        else {
                            foreach ($p in $catObj.PSObject.Properties) {
                                if ($p.Name -ne 'IsSingleInstance') { $baseProps[$p.Name] = $p.Value }
                            }
                        }
                    }

                    $resources += [PSCustomObject]@{
                        resourceType = $rt
                        displayName  = $rt
                        properties   = $baseProps
                    }
                }

                if ($skippedTypes.Count -gt 0) {
                    Write-Host ''
                    Write-Host ('  Note: {0} resource type(s) have no existing configuration and were excluded:' -f $skippedTypes.Count) -ForegroundColor Yellow
                    foreach ($st in $skippedTypes) {
                        Write-Host ('    - {0}' -f $st) -ForegroundColor Yellow
                    }
                }

                if ($resources.Count -eq 0) {
                    Write-Host ''
                    Write-Host '  No resource types could be resolved. Cannot create monitor.' -ForegroundColor Red
                    if ($discovery.SnapshotId) {
                        try { Remove-TBSnapshot -SnapshotId $discovery.SnapshotId -Confirm:$false } catch {}
                    }
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                # Re-confirm if types were filtered
                if ($skippedTypes.Count -gt 0) {
                    Write-Host ''
                    $reconfirmed = Read-TBUserInput -Prompt ('Create monitor with {0} resource type(s)?' -f $resources.Count) -Confirm
                    if (-not $reconfirmed) {
                        if ($discovery.SnapshotId) {
                            try { Remove-TBSnapshot -SnapshotId $discovery.SnapshotId -Confirm:$false } catch {}
                        }
                        return
                    }
                }

                $createParams = @{
                    DisplayName = $displayName
                    Resources   = $resources
                }
                if ($description) {
                    $createParams['Description'] = $description
                }

                $creation = Invoke-TBMonitorCreateWithRetry @createParams

                if ($creation.RejectedTypes.Count -gt 0) {
                    Write-Host ''
                    Write-Host ('  Note: {0} resource type(s) rejected by the monitor API:' -f $creation.RejectedTypes.Count) -ForegroundColor Yellow
                    foreach ($rj in $creation.RejectedTypes) {
                        Write-Host ('    - {0}' -f $rj) -ForegroundColor Yellow
                    }
                }

                if ($creation.Result) {
                    Write-Host ''
                    Write-Host ('  Monitor created: {0}' -f $creation.Result.Id) -ForegroundColor Green
                    Write-Host ('  Display Name: {0}' -f $creation.Result.DisplayName) -ForegroundColor White
                    Write-Host ('  Status: {0}' -f $creation.Result.Status) -ForegroundColor White
                }
                else {
                    Write-Host ''
                    Write-Host '  All resource types were rejected. Monitor was not created.' -ForegroundColor Red
                }

                # Best-effort cleanup of the temporary snapshot
                if ($discovery.SnapshotId) {
                    try { Remove-TBSnapshot -SnapshotId $discovery.SnapshotId -Confirm:$false } catch {}
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        2 { # List monitors
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
        3 { # View monitor details
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

                # Fetch and display baseline resources
                try {
                    $baseline = Get-TBBaseline -MonitorId $monitor.Id
                    $baselineResources = @($baseline.Resources)
                    if ($baselineResources.Count -gt 0) {
                        # Build catalog lookup tables for annotations
                        $catalog = Get-TBBaselineCatalog
                        $catLookup = @{}
                        $testLookup = @{}
                        foreach ($cat in $catalog.Categories) {
                            foreach ($rt in $cat.ResourceTypes) {
                                $catLookup[$rt] = $cat
                            }
                            foreach ($test in $cat.Tests) {
                                $key = '{0}|{1}' -f $test.ResourceType, $test.Property
                                if (-not $testLookup.ContainsKey($key)) {
                                    $testLookup[$key] = $test
                                }
                            }
                        }

                        Write-Host ''
                        Write-Host ('  Baseline: {0}' -f $baseline.DisplayName) -ForegroundColor Cyan
                        Write-Host ('  Resources ({0}):' -f $baselineResources.Count) -ForegroundColor Cyan
                        foreach ($res in $baselineResources) {
                            # Handle both hashtable and PSCustomObject responses
                            if ($res -is [hashtable]) {
                                $rtName = if ($res.ContainsKey('resourceType')) { $res['resourceType'] } else { '(unknown)' }
                                $resDisplay = if ($res.ContainsKey('displayName')) { $res['displayName'] } else { $rtName }
                                $props = if ($res.ContainsKey('properties')) { $res['properties'] } else { $null }
                            }
                            else {
                                $rtName = if ($res.PSObject.Properties['resourceType']) { $res.resourceType } else { '(unknown)' }
                                $resDisplay = if ($res.PSObject.Properties['displayName']) { $res.displayName } else { $rtName }
                                $props = if ($res.PSObject.Properties['properties']) { $res.properties } else { $null }
                            }
                            Write-Host ''
                            Write-Host ('    {0}' -f $resDisplay) -ForegroundColor White
                            Write-Host ('    Type: {0}' -f $rtName) -ForegroundColor DarkGray

                            # Show catalog source if resource type is in the EIDSCA catalog
                            $catInfo = $catLookup[$rtName]
                            if ($catInfo) {
                                Write-Host ('    Source: {0} - {1} [{2}]' -f $catInfo.Framework, $catInfo.Name, $catInfo.Severity) -ForegroundColor DarkGray
                            }

                            if ($props) {
                                $propNames = @()
                                if ($props -is [hashtable]) {
                                    $propNames = @($props.Keys | Sort-Object)
                                }
                                elseif ($props.PSObject.Properties) {
                                    $propNames = @($props.PSObject.Properties.Name | Sort-Object)
                                }

                                $displayableProps = @($propNames | Where-Object { $_ -ne 'IsSingleInstance' })
                                if ($displayableProps.Count -gt 0) {
                                    Write-Host ''
                                    Write-Host '    Baseline Property                         Desired Value' -ForegroundColor DarkCyan
                                    Write-Host '    -----------------                         -------------' -ForegroundColor DarkGray
                                    foreach ($pName in $displayableProps) {
                                        $pValue = if ($props -is [hashtable]) { $props[$pName] } else { $props.$pName }
                                        # Format arrays for display
                                        if ($pValue -is [System.Collections.IEnumerable] -and $pValue -isnot [string]) {
                                            $pValue = ($pValue -join ', ')
                                        }
                                        $pValueStr = "$pValue"
                                        if ($pValueStr.Length -gt 30) {
                                            $pValueStr = $pValueStr.Substring(0, 27) + '...'
                                        }
                                        Write-Host ('    {0}  {1}' -f $pName.PadRight(42), $pValueStr) -ForegroundColor White

                                        # Annotate with EIDSCA test description if available
                                        $testKey = '{0}|{1}' -f $rtName, $pName
                                        $testInfo = $testLookup[$testKey]
                                        if ($testInfo) {
                                            Write-Host ('      {0}' -f $testInfo.Description) -ForegroundColor DarkGray
                                        }
                                    }
                                }
                                else {
                                    Write-Host '    No baseline property values configured.' -ForegroundColor DarkGray
                                    Write-Host '    Tip: Create from security catalog to include recommended values.' -ForegroundColor DarkGray
                                }
                            }
                            else {
                                Write-Host '    No properties returned by API.' -ForegroundColor DarkGray
                            }
                        }
                    }
                }
                catch {
                    Write-Host ''
                    Write-Host ('  Could not load baseline: {0}' -f $_.Exception.Message) -ForegroundColor DarkGray
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        4 { # Update monitor
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
        5 { # Delete monitor
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
        6 { # View monitor results
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
        7 { # Pause/Resume monitor
            try {
                $monitors = @(Get-TBMonitor)
                if ($monitors.Count -eq 0) {
                    Write-Host ''
                    Write-Host '  No monitors found.' -ForegroundColor Yellow
                    Read-Host -Prompt '  Press Enter to continue'
                    return
                }

                $monitorOptions = foreach ($m in $monitors) {
                    '{0} - {1} ({2})' -f $m.DisplayName, $m.Id, $m.Status
                }

                $selected = Show-TBMenu -Title 'Select Monitor to Pause/Resume' -Options $monitorOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $monitor = $monitors[$selected]
                $newStatus = if ($monitor.Status -eq 'active') { 'inactive' } else { 'active' }
                $action = if ($newStatus -eq 'inactive') { 'Pause' } else { 'Resume' }

                $confirmed = Read-TBUserInput -Prompt ('{0} monitor "{1}"?' -f $action, $monitor.DisplayName) -Confirm
                if ($confirmed) {
                    Set-TBMonitor -MonitorId $monitor.Id -Status $newStatus -Confirm:$false
                    Write-Host ('  Monitor {0}d.' -f $action.ToLower()) -ForegroundColor Green
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        8 { # Clone monitor
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

                $selected = Show-TBMenu -Title 'Select Monitor to Clone' -Options $monitorOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $displayName = Read-TBUserInput -Prompt 'Display name for the clone' -Mandatory `
                    -MinLength 8 -MaxLength 32 `
                    -Pattern '^[a-zA-Z0-9 ]{8,32}$' `
                    -PatternMessage 'Must be 8-32 characters, alphanumeric and spaces only.'

                if (-not $displayName) { return }

                $result = Copy-TBMonitor -MonitorId $monitors[$selected].Id -DisplayName $displayName -Confirm:$false

                if ($result) {
                    Write-Host ''
                    Write-Host ('  Monitor cloned: {0}' -f $result.Id) -ForegroundColor Green
                    Write-Host ('  Display Name: {0}' -f $result.DisplayName) -ForegroundColor White
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        9 { # Export monitor
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

                $selected = Show-TBMenu -Title 'Select Monitor to Export' -Options $monitorOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $outputPath = Read-TBUserInput -Prompt 'Output file path (leave blank for default)'

                $exportParams = @{
                    MonitorId = $monitors[$selected].Id
                    Confirm   = $false
                }
                if ($outputPath) {
                    $exportParams['OutputPath'] = $outputPath
                }

                $result = Export-TBMonitor @exportParams
                Write-Host ''
                Write-Host ('  Monitor exported to: {0}' -f $result.OutputPath) -ForegroundColor Green
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        10 { # Quota status
            Write-Host ''
            Write-Host '  -- UTCM Quota Status --' -ForegroundColor Cyan
            Write-Host ''

            try {
                $quota = Get-TBQuotaStatus

                Write-Host ('  Monitors:              {0} / {1}' -f $quota.MonitorCount, $quota.MonitorLimit) -ForegroundColor White
                Write-Host ('  Baseline Resources:    {0}' -f $quota.TotalBaselineResources) -ForegroundColor White
                Write-Host ('  Resources/Day:         {0} / {1}' -f $quota.MonitoredResourcesPerDay, $quota.ResourceDayLimit) -ForegroundColor White
                Write-Host ('  Snapshot Jobs:         {0} / {1}' -f $quota.SnapshotJobCount, $quota.SnapshotJobLimit) -ForegroundColor White

                if ($quota.MonitorCount -ge 28) {
                    Write-Host ''
                    Write-Host '  Warning: Approaching monitor limit.' -ForegroundColor Yellow
                }
                if ($quota.MonitoredResourcesPerDay -ge 700) {
                    Write-Host ''
                    Write-Host '  Warning: Approaching daily resource evaluation limit.' -ForegroundColor Yellow
                }
                if ($quota.SnapshotJobCount -ge 10) {
                    Write-Host ''
                    Write-Host '  Warning: Approaching snapshot job limit.' -ForegroundColor Yellow
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
            'Create from Maester'
            'List monitors'
            'View monitor details'
            'Update monitor'
            'Delete monitor'
            'View monitor results'
            'Pause/Resume monitor'
            'Clone monitor'
            'Export monitor'
            'Quota status'
        )

        $choice = Show-TBMenu -Title 'Monitor Management' -Options $options -IncludeBack
        if ($choice -eq 'Back') { return }

        Invoke-TBMonitorAction -ActionIndex $choice
    }
}
