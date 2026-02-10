function Invoke-TBBaselineAction {
    <#
    .SYNOPSIS
        Executes a single baseline management action by index.
    .DESCRIPTION
        Contains the action logic extracted from Show-TBBaselineMenu's switch block.
        Called by both the classic submenu loop and the accordion direct-action path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ActionIndex
    )

    switch ($ActionIndex) {
        0 { # View baseline from monitor
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

                $baseline = Get-TBBaseline -MonitorId $monitors[$selected].Id
                Write-Host ''
                Write-Host '  -- Baseline Details --' -ForegroundColor Cyan
                Write-Host ('  ID:           {0}' -f $baseline.Id) -ForegroundColor White
                Write-Host ('  Monitor ID:   {0}' -f $baseline.MonitorId) -ForegroundColor White
                Write-Host ('  Display Name: {0}' -f $baseline.DisplayName) -ForegroundColor White
                Write-Host ('  Description:  {0}' -f $baseline.Description) -ForegroundColor White

                if ($baseline.Resources) {
                    Write-Host ('  Resources:    {0} resource(s)' -f @($baseline.Resources).Count) -ForegroundColor White
                    foreach ($res in $baseline.Resources) {
                        $resType = ''
                        $resName = ''
                        if ($res -is [hashtable]) {
                            $resType = $res['resourceType']
                            $resName = $res['displayName']
                        }
                        else {
                            if ($res.PSObject.Properties['resourceType']) { $resType = $res.resourceType }
                            if ($res.PSObject.Properties['displayName']) { $resName = $res.displayName }
                        }
                        Write-Host ('                - {0} ({1})' -f $resName, $resType) -ForegroundColor DarkGray
                    }
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        1 { # Export baseline
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

                $selected = Show-TBMenu -Title 'Select Monitor to Export Baseline' -Options $monitorOptions -IncludeBack
                if ($selected -eq 'Back') { return }

                $outputPath = Read-TBUserInput -Prompt 'Output file path (leave blank for default)'

                $exportParams = @{
                    MonitorId = $monitors[$selected].Id
                }
                if ($outputPath) {
                    $exportParams['OutputPath'] = $outputPath
                }

                $result = Export-TBBaseline @exportParams
                Write-Host ''
                Write-Host ('  Baseline exported to: {0}' -f $result.OutputPath) -ForegroundColor Green
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        2 { # Import baseline
            Write-Host ''
            Write-Host '  -- Import Baseline --' -ForegroundColor Cyan

            $path = Read-TBUserInput -Prompt 'Path to baseline JSON file' -Mandatory
            if (-not $path) { return }

            if (-not (Test-Path -Path $path -PathType Leaf)) {
                Write-Host '  File not found.' -ForegroundColor Red
                Read-Host -Prompt '  Press Enter to continue'
                return
            }

            try {
                $resources = @(Import-TBBaseline -Path $path)
                Write-Host ''
                Write-Host ('  Imported {0} resource(s) from baseline.' -f $resources.Count) -ForegroundColor Green

                $createMonitor = Read-TBUserInput -Prompt 'Create a monitor from this baseline?' -Confirm
                if ($createMonitor) {
                    $displayName = Read-TBUserInput -Prompt 'Monitor display name' -Mandatory `
                        -MinLength 8 -MaxLength 32 `
                        -Pattern '^[a-zA-Z0-9 ]{8,32}$' `
                        -PatternMessage 'Must be 8-32 characters, alphanumeric and spaces only.'

                    if ($displayName) {
                        $result = $resources | New-TBMonitor -DisplayName $displayName -Confirm:$false
                        Write-Host ('  Monitor created: {0}' -f $result.Id) -ForegroundColor Green
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

function Show-TBBaselineMenu {
    <#
    .SYNOPSIS
        Displays the baseline management submenu.
    .DESCRIPTION
        Interactive menu for viewing baselines and exporting/importing baselines.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$DirectAction = -1
    )

    if ($DirectAction -ge 0) {
        Invoke-TBBaselineAction -ActionIndex $DirectAction
        return
    }

    while ($true) {
        Clear-Host
        Write-TBMenuHeader -Subtitle 'Baseline Management'

        $options = @(
            'View baseline from monitor'
            'Export baseline'
            'Import baseline'
        )

        $choice = Show-TBMenu -Title 'Baseline Management' -Options $options -IncludeBack
        if ($choice -eq 'Back') { return }

        Invoke-TBBaselineAction -ActionIndex $choice
    }
}
