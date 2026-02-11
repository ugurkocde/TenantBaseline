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

                # Build baseline resources with IsSingleInstance key property
                $resources = foreach ($rt in $resourceTypes) {
                    [PSCustomObject]@{
                        resourceType = $rt
                        displayName  = $rt
                        properties   = @{ IsSingleInstance = 'Yes' }
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
                $params = @{
                    DisplayName = $displayName
                    Confirm     = $false
                }
                if ($description) {
                    $params['Description'] = $description
                }

                # Build resources from catalog BaselineResources with typed
                # EIDSCA recommended values as baseline properties.
                $resources = foreach ($rt in $resourceTypes) {
                    $baselineProps = $null
                    foreach ($cat in $catalog.Categories) {
                        foreach ($br in $cat.BaselineResources) {
                            if ($br.ResourceType -eq $rt) {
                                $baselineProps = $br.Properties
                                break
                            }
                        }
                        if ($baselineProps) { break }
                    }
                    if (-not $baselineProps) {
                        $baselineProps = @{ IsSingleInstance = 'Yes' }
                    }
                    [PSCustomObject]@{
                        resourceType = $rt
                        displayName  = $rt
                        properties   = $baselineProps
                    }
                }
                $params['Resources'] = $resources

                # Log what will be sent
                foreach ($r in $resources) {
                    $propCount = 0
                    if ($r.properties -is [hashtable]) {
                        $propCount = @($r.properties.Keys | Where-Object { $_ -ne 'IsSingleInstance' }).Count
                    }
                    elseif ($r.properties.PSObject.Properties) {
                        $propCount = @($r.properties.PSObject.Properties.Name | Where-Object { $_ -ne 'IsSingleInstance' }).Count
                    }
                    Write-Verbose ('  Resource: {0} with {1} baseline properties' -f $r.resourceType, $propCount)
                }

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
        )

        $choice = Show-TBMenu -Title 'Monitor Management' -Options $options -IncludeBack
        if ($choice -eq 'Back') { return }

        Invoke-TBMonitorAction -ActionIndex $choice
    }
}
