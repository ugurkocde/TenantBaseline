function New-TBDocumentation {
    <#
    .SYNOPSIS
        Generates tenant configuration monitoring documentation.
    .DESCRIPTION
        Collects monitoring data (monitors, baselines, snapshots, drifts)
        and generates a formatted document suitable for compliance review,
        knowledge sharing, or wiki embedding.
    .PARAMETER OutputPath
        The file path for the documentation output. Extension determines format
        (.html or .md). Defaults to TBDocumentation-{timestamp}.{html|md}.
    .PARAMETER Format
        Output format: HTML or Markdown. Defaults to HTML. If OutputPath has a
        recognized extension, that takes precedence.
    .PARAMETER IncludeDriftHistory
        Include a drift history section with summary breakdowns.
    .EXAMPLE
        New-TBDocumentation -OutputPath './docs/tenant-config.html'
    .EXAMPLE
        New-TBDocumentation -OutputPath './audit.md' -IncludeDriftHistory
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [ValidateSet('HTML', 'Markdown')]
        [string]$Format = 'HTML',

        [Parameter()]
        [switch]$IncludeDriftHistory
    )

    # Determine format from file extension if provided
    if ($OutputPath) {
        $extension = [System.IO.Path]::GetExtension($OutputPath).ToLower()
        if ($extension -eq '.md') {
            $Format = 'Markdown'
        }
        elseif ($extension -eq '.html' -or $extension -eq '.htm') {
            $Format = 'HTML'
        }
    }

    if (-not $OutputPath) {
        $dateStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $ext = if ($Format -eq 'Markdown') { '.md' } else { '.html' }
        $OutputPath = 'TBDocumentation-{0}{1}' -f $dateStamp, $ext
    }

    Write-TBLog -Message 'Collecting data for documentation'

    $monitors = @(Get-TBMonitor)

    # Collect baselines per monitor
    $baselines = @()
    foreach ($monitor in $monitors) {
        try {
            $bl = Get-TBBaseline -MonitorId $monitor.Id
            if ($bl) { $baselines += $bl }
        }
        catch {
            Write-TBLog -Message ('Could not retrieve baseline for monitor {0}: {1}' -f $monitor.Id, $_.Exception.Message) -Level 'Warning'
        }
    }

    $snapshots = @(Get-TBSnapshot)

    $driftSummary = $null
    if ($IncludeDriftHistory) {
        $driftSummary = Get-TBDriftSummary
    }

    $timestamp = (Get-Date).ToString('o')

    if ($PSCmdlet.ShouldProcess($OutputPath, 'Generate documentation')) {
        $parentDir = Split-Path -Path $OutputPath -Parent
        if ($parentDir -and -not (Test-Path -Path $parentDir)) {
            $null = New-Item -Path $parentDir -ItemType Directory -Force
        }

        $docParams = @{
            Monitors      = $monitors
            Baselines     = $baselines
            Snapshots     = $snapshots
            DriftSummary  = $driftSummary
            GeneratedAt   = $timestamp
        }

        if ($Format -eq 'Markdown') {
            $content = New-TBDocumentationMarkdown @docParams
        }
        else {
            $content = New-TBDocumentationHtml @docParams
        }

        $content | Out-File -FilePath $OutputPath -Encoding utf8 -Force

        Write-TBLog -Message ('Documentation generated: {0}' -f $OutputPath)

        [PSCustomObject]@{
            OutputPath    = (Resolve-Path -Path $OutputPath).Path
            Format        = $Format
            MonitorCount  = $monitors.Count
            BaselineCount = $baselines.Count
            SnapshotCount = $snapshots.Count
            GeneratedAt   = $timestamp
        }
    }
}

function New-TBDocumentationHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Monitors,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Baselines,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Snapshots,

        [Parameter()]
        $DriftSummary,

        [Parameter(Mandatory = $true)]
        [string]$GeneratedAt
    )

    $styleTokens = Get-TBFluentHtmlStyleTokenSet

    # Build Table of Contents entries
    $tocEntries = @(
        '<li><a href="#executive-summary">Executive Summary</a></li>'
        '<li><a href="#monitor-inventory">Monitor Inventory</a></li>'
        '<li><a href="#baseline-details">Baseline Details</a></li>'
        '<li><a href="#snapshot-inventory">Snapshot Inventory</a></li>'
    )
    if ($DriftSummary) {
        $tocEntries += '<li><a href="#drift-history">Drift History</a></li>'
    }
    $tocHtml = $tocEntries -join "`n            "

    # Executive Summary
    $summaryHtml = @"
    <section id="executive-summary">
        <h2>1. Executive Summary</h2>
        <div class="summary">
            <div class="card">
                <div class="label">Monitors</div>
                <div class="value">$($Monitors.Count)</div>
            </div>
            <div class="card">
                <div class="label">Baselines</div>
                <div class="value">$($Baselines.Count)</div>
            </div>
            <div class="card">
                <div class="label">Snapshots</div>
                <div class="value">$($Snapshots.Count)</div>
            </div>
        </div>
    </section>
"@

    # Monitor Inventory
    $monitorRows = ''
    foreach ($mon in $Monitors) {
        $mId = [System.Net.WebUtility]::HtmlEncode($mon.Id)
        $mName = ''
        $mDesc = ''
        $mStatus = ''
        $mFreq = ''

        if ($mon -is [hashtable]) {
            $mName = [System.Net.WebUtility]::HtmlEncode($mon['displayName'])
            $mDesc = [System.Net.WebUtility]::HtmlEncode($mon['description'])
            $mStatus = [System.Net.WebUtility]::HtmlEncode($mon['status'])
            $mFreq = $mon['monitorRunFrequencyInHours']
        }
        else {
            if ($mon.PSObject.Properties['DisplayName']) { $mName = [System.Net.WebUtility]::HtmlEncode($mon.DisplayName) }
            if ($mon.PSObject.Properties['Description']) { $mDesc = [System.Net.WebUtility]::HtmlEncode($mon.Description) }
            if ($mon.PSObject.Properties['Status']) { $mStatus = [System.Net.WebUtility]::HtmlEncode($mon.Status) }
            if ($mon.PSObject.Properties['MonitorRunFrequencyInHours']) { $mFreq = $mon.MonitorRunFrequencyInHours }
        }

        $statusClass = if ($mStatus -eq 'active') { 'status-active' } else { 'status-other' }

        $monitorRows += @"
            <tr>
                <td>$mName</td>
                <td><code>$mId</code></td>
                <td><span class="badge $statusClass">$mStatus</span></td>
                <td>${mFreq}h</td>
                <td>$mDesc</td>
            </tr>
"@
    }

    if (-not $monitorRows) {
        $monitorRows = '<tr><td colspan="5" style="text-align:center;">No monitors configured.</td></tr>'
    }

    $monitorHtml = @"
    <section id="monitor-inventory">
        <h2>2. Monitor Inventory</h2>
        <table>
            <thead>
                <tr>
                    <th>Name</th>
                    <th>ID</th>
                    <th>Status</th>
                    <th>Frequency</th>
                    <th>Description</th>
                </tr>
            </thead>
            <tbody>
$monitorRows
            </tbody>
        </table>
    </section>
"@

    # Baseline Details
    $baselineHtml = '<section id="baseline-details"><h2>3. Baseline Details</h2>'
    if ($Baselines.Count -eq 0) {
        $baselineHtml += '<p>No baselines found.</p>'
    }
    else {
        foreach ($bl in $Baselines) {
            $blName = ''
            $blDesc = ''
            $resources = @()

            if ($bl -is [hashtable]) {
                $blName = [System.Net.WebUtility]::HtmlEncode($bl['displayName'])
                $blDesc = [System.Net.WebUtility]::HtmlEncode($bl['description'])
                $resources = @($bl['resources'])
            }
            else {
                if ($bl.PSObject.Properties['DisplayName']) { $blName = [System.Net.WebUtility]::HtmlEncode($bl.DisplayName) }
                if ($bl.PSObject.Properties['Description']) { $blDesc = [System.Net.WebUtility]::HtmlEncode($bl.Description) }
                if ($bl.PSObject.Properties['Resources']) { $resources = @($bl.Resources) }
            }

            $baselineHtml += @"
        <div class="baseline-card">
            <h3>$blName</h3>
            <p>$blDesc</p>
"@

            foreach ($res in $resources) {
                $resName = ''
                $resType = ''
                $properties = @{}

                if ($res -is [hashtable]) {
                    $resName = [System.Net.WebUtility]::HtmlEncode($res['displayName'])
                    $resType = [System.Net.WebUtility]::HtmlEncode($res['resourceType'])
                    if ($res['properties']) { $properties = $res['properties'] }
                }
                else {
                    if ($res.PSObject.Properties['displayName']) { $resName = [System.Net.WebUtility]::HtmlEncode($res.displayName) }
                    if ($res.PSObject.Properties['resourceType']) { $resType = [System.Net.WebUtility]::HtmlEncode($res.resourceType) }
                    if ($res.PSObject.Properties['properties']) { $properties = $res.properties }
                }

                $baselineHtml += @"
            <h4>$resName <small>($resType)</small></h4>
            <table class="props-table">
                <thead><tr><th>Property</th><th>Value</th></tr></thead>
                <tbody>
"@

                $propsList = @()
                if ($properties -is [hashtable]) {
                    foreach ($key in $properties.Keys) {
                        $propsList += @{ Name = $key; Value = "$($properties[$key])" }
                    }
                }
                elseif ($properties) {
                    foreach ($prop in $properties.PSObject.Properties) {
                        $propsList += @{ Name = $prop.Name; Value = "$($prop.Value)" }
                    }
                }

                if ($propsList.Count -eq 0) {
                    $baselineHtml += '<tr><td colspan="2" style="text-align:center;">No properties defined.</td></tr>'
                }
                else {
                    foreach ($p in $propsList) {
                        $pName = [System.Net.WebUtility]::HtmlEncode($p.Name)
                        $pVal = [System.Net.WebUtility]::HtmlEncode($p.Value)
                        $baselineHtml += "                <tr><td>$pName</td><td><code>$pVal</code></td></tr>`n"
                    }
                }

                $baselineHtml += @"
                </tbody>
            </table>
"@
            }

            $baselineHtml += '        </div>'
        }
    }
    $baselineHtml += '</section>'

    # Snapshot Inventory
    $snapshotRows = ''
    foreach ($snap in $Snapshots) {
        $sName = ''
        $sId = ''
        $sStatus = ''
        $sCreated = ''
        $sCompleted = ''
        $sResources = ''

        if ($snap -is [hashtable]) {
            $sName = [System.Net.WebUtility]::HtmlEncode($snap['displayName'])
            $sId = [System.Net.WebUtility]::HtmlEncode($snap['id'])
            $sStatus = [System.Net.WebUtility]::HtmlEncode($snap['status'])
            $sCreated = [System.Net.WebUtility]::HtmlEncode($snap['createdDateTime'])
            $sCompleted = if ($snap['completedDateTime']) { [System.Net.WebUtility]::HtmlEncode($snap['completedDateTime']) } else { '-' }
            if ($snap['resources']) { $sResources = [System.Net.WebUtility]::HtmlEncode(($snap['resources'] -join ', ')) }
        }
        else {
            if ($snap.PSObject.Properties['DisplayName']) { $sName = [System.Net.WebUtility]::HtmlEncode($snap.DisplayName) }
            if ($snap.PSObject.Properties['Id']) { $sId = [System.Net.WebUtility]::HtmlEncode($snap.Id) }
            if ($snap.PSObject.Properties['Status']) { $sStatus = [System.Net.WebUtility]::HtmlEncode($snap.Status) }
            if ($snap.PSObject.Properties['CreatedDateTime']) { $sCreated = [System.Net.WebUtility]::HtmlEncode("$($snap.CreatedDateTime)") }
            $sCompleted = '-'
            if ($snap.PSObject.Properties['CompletedDateTime'] -and $snap.CompletedDateTime) {
                $sCompleted = [System.Net.WebUtility]::HtmlEncode("$($snap.CompletedDateTime)")
            }
            if ($snap.PSObject.Properties['Resources']) { $sResources = [System.Net.WebUtility]::HtmlEncode(($snap.Resources -join ', ')) }
        }

        $snapshotRows += @"
            <tr>
                <td>$sName</td>
                <td><code>$sId</code></td>
                <td>$sStatus</td>
                <td>$sCreated</td>
                <td>$sCompleted</td>
                <td>$sResources</td>
            </tr>
"@
    }

    if (-not $snapshotRows) {
        $snapshotRows = '<tr><td colspan="6" style="text-align:center;">No snapshots found.</td></tr>'
    }

    $snapshotHtml = @"
    <section id="snapshot-inventory">
        <h2>4. Snapshot Inventory</h2>
        <table>
            <thead>
                <tr>
                    <th>Name</th>
                    <th>ID</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th>Completed</th>
                    <th>Resources</th>
                </tr>
            </thead>
            <tbody>
$snapshotRows
            </tbody>
        </table>
    </section>
"@

    # Drift History (optional)
    $driftHtml = ''
    if ($DriftSummary) {
        $totalDrifts = 0
        $totalProps = 0

        if ($DriftSummary -is [hashtable]) {
            $totalDrifts = $DriftSummary['TotalDrifts']
            $totalProps = $DriftSummary['TotalDriftedProperties']
        }
        else {
            if ($DriftSummary.PSObject.Properties['TotalDrifts']) { $totalDrifts = $DriftSummary.TotalDrifts }
            if ($DriftSummary.PSObject.Properties['TotalDriftedProperties']) { $totalProps = $DriftSummary.TotalDriftedProperties }
        }

        $statusRows = ''
        $byStatus = $null
        if ($DriftSummary -is [hashtable]) {
            $byStatus = $DriftSummary['ByStatus']
        }
        elseif ($DriftSummary.PSObject.Properties['ByStatus']) {
            $byStatus = $DriftSummary.ByStatus
        }

        if ($byStatus) {
            if ($byStatus -is [hashtable]) {
                foreach ($key in $byStatus.Keys) {
                    $statusRows += ('<tr><td>{0}</td><td>{1}</td></tr>' -f [System.Net.WebUtility]::HtmlEncode($key), $byStatus[$key])
                }
            }
            else {
                foreach ($prop in $byStatus.PSObject.Properties) {
                    $statusRows += ('<tr><td>{0}</td><td>{1}</td></tr>' -f [System.Net.WebUtility]::HtmlEncode($prop.Name), $prop.Value)
                }
            }
        }

        if (-not $statusRows) {
            $statusRows = '<tr><td colspan="2" style="text-align:center;">No drift data.</td></tr>'
        }

        $resourceRows = ''
        $byResourceType = $null
        if ($DriftSummary -is [hashtable]) {
            $byResourceType = $DriftSummary['ByResourceType']
        }
        elseif ($DriftSummary.PSObject.Properties['ByResourceType']) {
            $byResourceType = $DriftSummary.ByResourceType
        }

        if ($byResourceType) {
            if ($byResourceType -is [hashtable]) {
                foreach ($key in $byResourceType.Keys) {
                    $resourceRows += ('<tr><td>{0}</td><td>{1}</td></tr>' -f [System.Net.WebUtility]::HtmlEncode($key), $byResourceType[$key])
                }
            }
            else {
                foreach ($prop in $byResourceType.PSObject.Properties) {
                    $resourceRows += ('<tr><td>{0}</td><td>{1}</td></tr>' -f [System.Net.WebUtility]::HtmlEncode($prop.Name), $prop.Value)
                }
            }
        }

        if (-not $resourceRows) {
            $resourceRows = '<tr><td colspan="2" style="text-align:center;">No drift data.</td></tr>'
        }

        $driftSectionNum = '5'
        $alertClass = if ($totalDrifts -gt 0) { ' alert' } else { '' }

        $driftHtml = @"
    <section id="drift-history">
        <h2>$driftSectionNum. Drift History</h2>
        <div class="summary">
            <div class="card$alertClass">
                <div class="label">Total Drifts</div>
                <div class="value">$totalDrifts</div>
            </div>
            <div class="card">
                <div class="label">Drifted Properties</div>
                <div class="value">$totalProps</div>
            </div>
        </div>

        <h3>By Status</h3>
        <table class="compact-table">
            <thead><tr><th>Status</th><th>Count</th></tr></thead>
            <tbody>$statusRows</tbody>
        </table>

        <h3>By Resource Type</h3>
        <table class="compact-table">
            <thead><tr><th>Resource Type</th><th>Count</th></tr></thead>
            <tbody>$resourceRows</tbody>
        </table>
    </section>
"@
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Tenant Configuration Monitoring Documentation</title>
    <style>
$styleTokens
        body { margin: 2rem auto; max-width: 1120px; }
        h1 { color: var(--tb-accent); border-bottom: 2px solid var(--tb-accent); padding-bottom: 0.5rem; }
        h2 { color: var(--tb-text); margin-top: 2rem; border-bottom: 1px solid var(--tb-border); padding-bottom: 0.3rem; }
        h3 { color: var(--tb-text-muted); margin-top: 1.5rem; }
        h4 { color: var(--tb-text); margin-top: 1rem; }
        h4 small { color: var(--tb-text-muted); font-weight: normal; }
        nav { border-radius: 8px; padding: 1rem 1.5rem; margin: 1rem 0; }
        nav ol { margin: 0; padding-left: 1.5rem; }
        nav li { margin: 0.3rem 0; }
        nav a { color: var(--tb-accent); text-decoration: none; }
        nav a:hover { text-decoration: underline; }
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
        .badge { padding: 0.2rem 0.6rem; border-radius: 3px; font-size: 0.85rem; font-weight: 600; }
        .status-active { background: #dff6dd; color: var(--tb-success); }
        .status-other { background: var(--tb-surface-muted); color: var(--tb-text-muted); }
        .baseline-card { border-radius: 8px; padding: 1rem 1.5rem; margin: 1rem 0; }
        .props-table { max-width: 600px; }
        .compact-table { max-width: 400px; }
        .footer { margin-top: 2rem; padding-top: 1rem; border-top: 1px solid var(--tb-border); color: var(--tb-text-muted); font-size: 0.85rem; }
        @media print {
            body { margin: 0; background: #fff; }
            .card { box-shadow: none; border: 1px solid #ccc; }
            table { box-shadow: none; }
            nav a { color: #000; }
        }
    </style>
</head>
<body>
    <h1>Tenant Configuration Monitoring Documentation</h1>
    <p>Generated: $([System.Net.WebUtility]::HtmlEncode($GeneratedAt))</p>

    <nav>
        <strong>Table of Contents</strong>
        <ol>
            $tocHtml
        </ol>
    </nav>

$summaryHtml

$monitorHtml

$baselineHtml

$snapshotHtml

$driftHtml

    <div class="footer">
        <p>Generated by TenantBaseline PowerShell Module</p>
    </div>
</body>
</html>
"@

    return $html
}

function New-TBDocumentationMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Monitors,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Baselines,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Snapshots,

        [Parameter()]
        $DriftSummary,

        [Parameter(Mandatory = $true)]
        [string]$GeneratedAt
    )

    $lines = [System.Collections.ArrayList]::new()

    $null = $lines.Add('# Tenant Configuration Monitoring Documentation')
    $null = $lines.Add('')
    $null = $lines.Add(('Generated: {0}' -f $GeneratedAt))
    $null = $lines.Add('')

    # Table of Contents
    $null = $lines.Add('## Table of Contents')
    $null = $lines.Add('')
    $null = $lines.Add('1. [Executive Summary](#executive-summary)')
    $null = $lines.Add('2. [Monitor Inventory](#monitor-inventory)')
    $null = $lines.Add('3. [Baseline Details](#baseline-details)')
    $null = $lines.Add('4. [Snapshot Inventory](#snapshot-inventory)')
    if ($DriftSummary) {
        $null = $lines.Add('5. [Drift History](#drift-history)')
    }
    $null = $lines.Add('')

    # Executive Summary
    $null = $lines.Add('## Executive Summary')
    $null = $lines.Add('')
    $null = $lines.Add(('- **Monitors**: {0}' -f $Monitors.Count))
    $null = $lines.Add(('- **Baselines**: {0}' -f $Baselines.Count))
    $null = $lines.Add(('- **Snapshots**: {0}' -f $Snapshots.Count))
    $null = $lines.Add('')

    # Monitor Inventory
    $null = $lines.Add('## Monitor Inventory')
    $null = $lines.Add('')
    if ($Monitors.Count -eq 0) {
        $null = $lines.Add('No monitors configured.')
    }
    else {
        $null = $lines.Add('| Name | ID | Status | Frequency | Description |')
        $null = $lines.Add('|------|-----|--------|-----------|-------------|')

        foreach ($mon in $Monitors) {
            $mName = ''
            $mId = ''
            $mStatus = ''
            $mFreq = ''
            $mDesc = ''

            if ($mon -is [hashtable]) {
                $mName = $mon['displayName']
                $mId = $mon['id']
                $mStatus = $mon['status']
                $mFreq = $mon['monitorRunFrequencyInHours']
                $mDesc = $mon['description']
            }
            else {
                if ($mon.PSObject.Properties['DisplayName']) { $mName = $mon.DisplayName }
                if ($mon.PSObject.Properties['Id']) { $mId = $mon.Id }
                if ($mon.PSObject.Properties['Status']) { $mStatus = $mon.Status }
                if ($mon.PSObject.Properties['MonitorRunFrequencyInHours']) { $mFreq = $mon.MonitorRunFrequencyInHours }
                if ($mon.PSObject.Properties['Description']) { $mDesc = $mon.Description }
            }

            $null = $lines.Add(('| {0} | `{1}` | {2} | {3}h | {4} |' -f $mName, $mId, $mStatus, $mFreq, $mDesc))
        }
    }
    $null = $lines.Add('')

    # Baseline Details
    $null = $lines.Add('## Baseline Details')
    $null = $lines.Add('')

    if ($Baselines.Count -eq 0) {
        $null = $lines.Add('No baselines found.')
    }
    else {
        foreach ($bl in $Baselines) {
            $blName = ''
            $blDesc = ''
            $resources = @()

            if ($bl -is [hashtable]) {
                $blName = $bl['displayName']
                $blDesc = $bl['description']
                $resources = @($bl['resources'])
            }
            else {
                if ($bl.PSObject.Properties['DisplayName']) { $blName = $bl.DisplayName }
                if ($bl.PSObject.Properties['Description']) { $blDesc = $bl.Description }
                if ($bl.PSObject.Properties['Resources']) { $resources = @($bl.Resources) }
            }

            $null = $lines.Add(('### {0}' -f $blName))
            $null = $lines.Add('')
            if ($blDesc) {
                $null = $lines.Add($blDesc)
                $null = $lines.Add('')
            }

            foreach ($res in $resources) {
                $resName = ''
                $resType = ''
                $properties = @{}

                if ($res -is [hashtable]) {
                    $resName = $res['displayName']
                    $resType = $res['resourceType']
                    if ($res['properties']) { $properties = $res['properties'] }
                }
                else {
                    if ($res.PSObject.Properties['displayName']) { $resName = $res.displayName }
                    if ($res.PSObject.Properties['resourceType']) { $resType = $res.resourceType }
                    if ($res.PSObject.Properties['properties']) { $properties = $res.properties }
                }

                $null = $lines.Add(('#### {0} ({1})' -f $resName, $resType))
                $null = $lines.Add('')
                $null = $lines.Add('| Property | Value |')
                $null = $lines.Add('|----------|-------|')

                $propsList = @()
                if ($properties -is [hashtable]) {
                    foreach ($key in $properties.Keys) {
                        $propsList += @{ Name = $key; Value = "$($properties[$key])" }
                    }
                }
                elseif ($properties) {
                    foreach ($prop in $properties.PSObject.Properties) {
                        $propsList += @{ Name = $prop.Name; Value = "$($prop.Value)" }
                    }
                }

                if ($propsList.Count -eq 0) {
                    $null = $lines.Add('| (none) | - |')
                }
                else {
                    foreach ($p in $propsList) {
                        $null = $lines.Add(('| {0} | `{1}` |' -f $p.Name, $p.Value))
                    }
                }

                $null = $lines.Add('')
            }
        }
    }

    # Snapshot Inventory
    $null = $lines.Add('## Snapshot Inventory')
    $null = $lines.Add('')
    if ($Snapshots.Count -eq 0) {
        $null = $lines.Add('No snapshots found.')
    }
    else {
        $null = $lines.Add('| Name | ID | Status | Created | Completed | Resources |')
        $null = $lines.Add('|------|-----|--------|---------|-----------|-----------|')

        foreach ($snap in $Snapshots) {
            $sName = ''
            $sId = ''
            $sStatus = ''
            $sCreated = ''
            $sCompleted = '-'
            $sResources = ''

            if ($snap -is [hashtable]) {
                $sName = $snap['displayName']
                $sId = $snap['id']
                $sStatus = $snap['status']
                $sCreated = $snap['createdDateTime']
                if ($snap['completedDateTime']) { $sCompleted = $snap['completedDateTime'] }
                if ($snap['resources']) { $sResources = ($snap['resources'] -join ', ') }
            }
            else {
                if ($snap.PSObject.Properties['DisplayName']) { $sName = $snap.DisplayName }
                if ($snap.PSObject.Properties['Id']) { $sId = $snap.Id }
                if ($snap.PSObject.Properties['Status']) { $sStatus = $snap.Status }
                if ($snap.PSObject.Properties['CreatedDateTime']) { $sCreated = "$($snap.CreatedDateTime)" }
                if ($snap.PSObject.Properties['CompletedDateTime'] -and $snap.CompletedDateTime) { $sCompleted = "$($snap.CompletedDateTime)" }
                if ($snap.PSObject.Properties['Resources']) { $sResources = ($snap.Resources -join ', ') }
            }

            $null = $lines.Add(('| {0} | `{1}` | {2} | {3} | {4} | {5} |' -f $sName, $sId, $sStatus, $sCreated, $sCompleted, $sResources))
        }
    }
    $null = $lines.Add('')

    # Drift History (optional)
    if ($DriftSummary) {
        $totalDrifts = 0
        $totalProps = 0

        if ($DriftSummary -is [hashtable]) {
            $totalDrifts = $DriftSummary['TotalDrifts']
            $totalProps = $DriftSummary['TotalDriftedProperties']
        }
        else {
            if ($DriftSummary.PSObject.Properties['TotalDrifts']) { $totalDrifts = $DriftSummary.TotalDrifts }
            if ($DriftSummary.PSObject.Properties['TotalDriftedProperties']) { $totalProps = $DriftSummary.TotalDriftedProperties }
        }

        $null = $lines.Add('## Drift History')
        $null = $lines.Add('')
        $null = $lines.Add(('- **Total Drifts**: {0}' -f $totalDrifts))
        $null = $lines.Add(('- **Total Drifted Properties**: {0}' -f $totalProps))
        $null = $lines.Add('')

        $null = $lines.Add('### By Status')
        $null = $lines.Add('')
        $null = $lines.Add('| Status | Count |')
        $null = $lines.Add('|--------|-------|')

        $byStatus = $null
        if ($DriftSummary -is [hashtable]) {
            $byStatus = $DriftSummary['ByStatus']
        }
        elseif ($DriftSummary.PSObject.Properties['ByStatus']) {
            $byStatus = $DriftSummary.ByStatus
        }

        if ($byStatus) {
            if ($byStatus -is [hashtable]) {
                foreach ($key in $byStatus.Keys) {
                    $null = $lines.Add(('| {0} | {1} |' -f $key, $byStatus[$key]))
                }
            }
            else {
                foreach ($prop in $byStatus.PSObject.Properties) {
                    $null = $lines.Add(('| {0} | {1} |' -f $prop.Name, $prop.Value))
                }
            }
        }

        $null = $lines.Add('')
        $null = $lines.Add('### By Resource Type')
        $null = $lines.Add('')
        $null = $lines.Add('| Resource Type | Count |')
        $null = $lines.Add('|---------------|-------|')

        $byResourceType = $null
        if ($DriftSummary -is [hashtable]) {
            $byResourceType = $DriftSummary['ByResourceType']
        }
        elseif ($DriftSummary.PSObject.Properties['ByResourceType']) {
            $byResourceType = $DriftSummary.ByResourceType
        }

        if ($byResourceType) {
            if ($byResourceType -is [hashtable]) {
                foreach ($key in $byResourceType.Keys) {
                    $null = $lines.Add(('| {0} | {1} |' -f $key, $byResourceType[$key]))
                }
            }
            else {
                foreach ($prop in $byResourceType.PSObject.Properties) {
                    $null = $lines.Add(('| {0} | {1} |' -f $prop.Name, $prop.Value))
                }
            }
        }

        $null = $lines.Add('')
    }

    $null = $lines.Add('---')
    $null = $lines.Add('')
    $null = $lines.Add('*Generated by TenantBaseline PowerShell Module*')

    return ($lines -join "`n")
}
