function New-TBDriftReport {
    <#
    .SYNOPSIS
        Generates an HTML or JSON drift report.
    .DESCRIPTION
        Collects drift data and monitor information, then generates a formatted
        report for review and compliance documentation.
    .PARAMETER OutputPath
        The file path for the report. Extension determines format (.html or .json).
    .PARAMETER MonitorId
        Optional monitor ID to scope the report.
    .PARAMETER Format
        Report format: HTML or JSON. Defaults to HTML. If OutputPath has an extension,
        that takes precedence.
    .EXAMPLE
        New-TBDriftReport -OutputPath './drift-report.html'
    .EXAMPLE
        New-TBDriftReport -OutputPath './drift-report.json' -MonitorId '00000000-...'
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [string]$MonitorId,

        [Parameter()]
        [ValidateSet('HTML', 'JSON')]
        [string]$Format = 'HTML'
    )

    # Determine format from file extension if provided
    if ($OutputPath) {
        $extension = [System.IO.Path]::GetExtension($OutputPath).ToLower()
        if ($extension -eq '.json') {
            $Format = 'JSON'
        }
        elseif ($extension -eq '.html' -or $extension -eq '.htm') {
            $Format = 'HTML'
        }
    }

    if (-not $OutputPath) {
        $dateStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $ext = if ($Format -eq 'JSON') { '.json' } else { '.html' }
        $OutputPath = 'TBDriftReport-{0}{1}' -f $dateStamp, $ext
    }

    $driftParams = @{}
    if ($MonitorId) {
        $driftParams['MonitorId'] = $MonitorId
    }

    Write-TBLog -Message 'Collecting drift data for report'
    $drifts = @(Get-TBDrift @driftParams)
    $summary = Get-TBDriftSummary @driftParams
    $monitors = @(Get-TBMonitor)

    $reportData = [PSCustomObject]@{
        GeneratedAt    = (Get-Date).ToString('o')
        TotalDrifts    = $drifts.Count
        TotalMonitors  = $monitors.Count
        Summary        = $summary
        Drifts         = $drifts
        Monitors       = $monitors
    }

    if ($PSCmdlet.ShouldProcess($OutputPath, 'Generate drift report')) {
        $parentDir = Split-Path -Path $OutputPath -Parent
        if ($parentDir -and -not (Test-Path -Path $parentDir)) {
            $null = New-Item -Path $parentDir -ItemType Directory -Force
        }

        if ($Format -eq 'JSON') {
            $reportData | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputPath -Encoding utf8 -Force
        }
        else {
            $html = New-TBDriftReportHtml -ReportData $reportData
            $html | Out-File -FilePath $OutputPath -Encoding utf8 -Force
        }

        Write-TBLog -Message ('Report generated: {0}' -f $OutputPath)

        [PSCustomObject]@{
            OutputPath  = (Resolve-Path -Path $OutputPath).Path
            Format      = $Format
            DriftCount  = $drifts.Count
            GeneratedAt = $reportData.GeneratedAt
        }
    }
}

function New-TBDriftReportHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ReportData
    )

    $styleTokens = Get-TBFluentHtmlStyleTokenSet

    $driftRows = ''
    foreach ($drift in $ReportData.Drifts) {
        $resourceType = [System.Net.WebUtility]::HtmlEncode($drift.ResourceType)
        $displayName = [System.Net.WebUtility]::HtmlEncode($drift.BaselineResourceDisplayName)
        $status = [System.Net.WebUtility]::HtmlEncode($drift.Status)
        $detected = [System.Net.WebUtility]::HtmlEncode($drift.FirstReportedDateTime)

        if ($drift.DriftedProperties) {
            foreach ($prop in $drift.DriftedProperties) {
                $propName = ''
                $desired = ''
                $current = ''

                if ($prop -is [hashtable]) {
                    $propName = $prop['propertyName']
                    $desired = "$($prop['desiredValue'])"
                    $current = "$($prop['currentValue'])"
                }
                else {
                    if ($prop.PSObject.Properties['propertyName']) { $propName = $prop.propertyName }
                    if ($prop.PSObject.Properties['desiredValue']) { $desired = "$($prop.desiredValue)" }
                    if ($prop.PSObject.Properties['currentValue']) { $current = "$($prop.currentValue)" }
                }

                $driftRows += @"
        <tr>
            <td>$resourceType</td>
            <td>$([System.Net.WebUtility]::HtmlEncode($displayName))</td>
            <td>$([System.Net.WebUtility]::HtmlEncode($propName))</td>
            <td><code>$([System.Net.WebUtility]::HtmlEncode($desired))</code></td>
            <td><code>$([System.Net.WebUtility]::HtmlEncode($current))</code></td>
            <td>$status</td>
            <td>$detected</td>
        </tr>
"@
            }
        }
        else {
            $driftRows += @"
        <tr>
            <td>$resourceType</td>
            <td>$([System.Net.WebUtility]::HtmlEncode($displayName))</td>
            <td>-</td>
            <td>-</td>
            <td>-</td>
            <td>$status</td>
            <td>$detected</td>
        </tr>
"@
        }
    }

    if (-not $driftRows) {
        $driftRows = '<tr><td colspan="7" style="text-align:center;">No drifts detected.</td></tr>'
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TenantBaseline Drift Report</title>
    <style>
$styleTokens
        body { margin: 2rem; }
        h1 { color: var(--tb-accent); border-bottom: 2px solid var(--tb-accent); padding-bottom: 0.5rem; }
        h2 { color: var(--tb-text); margin-top: 2rem; }
        .summary { display: flex; gap: 1rem; flex-wrap: wrap; margin: 1rem 0; }
        .card { border-radius: 8px; padding: 1rem 1.5rem; min-width: 150px; }
        .card .label { font-size: 0.85rem; color: var(--tb-text-muted); text-transform: uppercase; letter-spacing: 0.5px; }
        .card .value { font-size: 2rem; font-weight: 600; color: var(--tb-text); }
        .card.alert .value { color: var(--tb-danger); }
        table { width: 100%; border-collapse: collapse; margin: 1rem 0; border-radius: 8px; overflow: hidden; }
        th { background: var(--tb-accent); color: #fff; text-align: left; padding: 0.75rem 1rem; font-weight: 600; }
        td { padding: 0.5rem 1rem; border-bottom: 1px solid var(--tb-border); }
        tr:hover td { background: var(--tb-surface-muted); }
        code { background: var(--tb-surface-muted); padding: 0.15rem 0.4rem; border-radius: 4px; font-size: 0.9em; }
        .footer { margin-top: 2rem; padding-top: 1rem; border-top: 1px solid var(--tb-border); color: var(--tb-text-muted); font-size: 0.85rem; }
    </style>
</head>
<body>
    <h1>TenantBaseline Drift Report</h1>
    <p>Generated: $([System.Net.WebUtility]::HtmlEncode($ReportData.GeneratedAt))</p>

    <div class="summary">
        <div class="card$(if ($ReportData.TotalDrifts -gt 0) { ' alert' })">
            <div class="label">Drifts Detected</div>
            <div class="value">$($ReportData.TotalDrifts)</div>
        </div>
        <div class="card">
            <div class="label">Monitors</div>
            <div class="value">$($ReportData.TotalMonitors)</div>
        </div>
    </div>

    <h2>Drift Details</h2>
    <table>
        <thead>
            <tr>
                <th>Resource Type</th>
                <th>Resource</th>
                <th>Property</th>
                <th>Desired Value</th>
                <th>Current Value</th>
                <th>Status</th>
                <th>First Detected</th>
            </tr>
        </thead>
        <tbody>
            $driftRows
        </tbody>
    </table>

    <div class="footer">
        <p>Generated by TenantBaseline PowerShell Module</p>
    </div>
</body>
</html>
"@

    return $html
}
