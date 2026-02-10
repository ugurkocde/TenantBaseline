function Invoke-TBReportAction {
    <#
    .SYNOPSIS
        Executes a single report/documentation action by index.
    .DESCRIPTION
        Contains the action logic extracted from Show-TBReportMenu's switch block.
        Called by both the classic submenu loop and the accordion direct-action path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ActionIndex
    )

    switch ($ActionIndex) {
        0 { # Generate drift report
            Write-Host ''
            Write-Host '  -- Generate Drift Report --' -ForegroundColor Cyan

            $formatOptions = @('HTML', 'JSON')
            $formatChoice = Show-TBMenu -Title 'Report Format' -Options $formatOptions -IncludeBack
            if ($formatChoice -eq 'Back') { return }

            $format = $formatOptions[$formatChoice]
            $outputPath = Read-TBUserInput -Prompt 'Output file path (leave blank for default)'

            $reportParams = @{
                Format  = $format
                Confirm = $false
            }
            if ($outputPath) {
                $reportParams['OutputPath'] = $outputPath
            }

            try {
                $result = New-TBDriftReport @reportParams
                Write-Host ''
                Write-Host ('  Report generated: {0}' -f $result.OutputPath) -ForegroundColor Green
                Write-Host ('  Format: {0}' -f $result.Format) -ForegroundColor White
                Write-Host ('  Drifts: {0}' -f $result.DriftCount) -ForegroundColor White
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        1 { # Generate dashboard
            Write-Host ''
            Write-Host '  -- Generate Dashboard --' -ForegroundColor Cyan

            $snapshotOptions = @('No', 'Yes')
            $snapChoice = Show-TBMenu -Title 'Include snapshots?' -Options $snapshotOptions -IncludeBack
            if ($snapChoice -eq 'Back') { return }

            $outputPath = Read-TBUserInput -Prompt 'Output file path (leave blank for default)'

            $dashParams = @{
                Confirm = $false
            }
            if ($outputPath) {
                $dashParams['OutputPath'] = $outputPath
            }
            if ($snapChoice -eq 1) {
                $dashParams['IncludeSnapshots'] = $true
            }

            try {
                $result = New-TBDashboard @dashParams
                Write-Host ''
                Write-Host ('  Dashboard generated: {0}' -f $result.OutputPath) -ForegroundColor Green
                Write-Host ('  Monitors: {0}' -f $result.MonitorCount) -ForegroundColor White
                Write-Host ('  Drifts: {0}' -f $result.DriftCount) -ForegroundColor White
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        2 { # Generate documentation
            Write-Host ''
            Write-Host '  -- Generate Documentation --' -ForegroundColor Cyan

            $formatOptions = @('HTML', 'Markdown')
            $formatChoice = Show-TBMenu -Title 'Documentation Format' -Options $formatOptions -IncludeBack
            if ($formatChoice -eq 'Back') { return }

            $format = $formatOptions[$formatChoice]

            $includeOptions = @('No', 'Yes')

            $driftChoice = Show-TBMenu -Title 'Include drift history?' -Options $includeOptions -IncludeBack
            if ($driftChoice -eq 'Back') { return }

            $outputPath = Read-TBUserInput -Prompt 'Output file path (leave blank for default)'

            $docParams = @{
                Format  = $format
                Confirm = $false
            }
            if ($outputPath) {
                $docParams['OutputPath'] = $outputPath
            }
            if ($driftChoice -eq 1) {
                $docParams['IncludeDriftHistory'] = $true
            }

            try {
                $result = New-TBDocumentation @docParams
                Write-Host ''
                Write-Host ('  Documentation generated: {0}' -f $result.OutputPath) -ForegroundColor Green
                Write-Host ('  Format: {0}' -f $result.Format) -ForegroundColor White
                Write-Host ('  Monitors: {0}' -f $result.MonitorCount) -ForegroundColor White
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
    }
}

function Show-TBReportMenu {
    <#
    .SYNOPSIS
        Displays the reports and documentation submenu.
    .DESCRIPTION
        Interactive menu for generating drift reports, dashboards, and
        tenant configuration documentation.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$DirectAction = -1
    )

    if ($DirectAction -ge 0) {
        Invoke-TBReportAction -ActionIndex $DirectAction
        return
    }

    while ($true) {
        Clear-Host
        Write-TBMenuHeader -Subtitle 'Reports and Documentation'

        $options = @(
            'Generate drift report'
            'Generate dashboard'
            'Generate documentation'
        )

        $choice = Show-TBMenu -Title 'Reports and Documentation' -Options $options -IncludeBack
        if ($choice -eq 'Back') { return }

        Invoke-TBReportAction -ActionIndex $choice
    }
}
