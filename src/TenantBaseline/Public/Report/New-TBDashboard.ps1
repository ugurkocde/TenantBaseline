function New-TBDashboard {
    <#
    .SYNOPSIS
        Generates an interactive HTML dashboard for tenant configuration monitoring.
    .DESCRIPTION
        Collects monitoring data and generates a self-contained, offline-capable
        HTML dashboard with drift timelines, monitor details, and optional snapshot
        comparison. All data is embedded as JSON within the HTML file.
    .PARAMETER OutputPath
        The file path for the dashboard HTML file.
        Defaults to TBDashboard-{timestamp}.html.
    .PARAMETER MonitorId
        Optional monitor ID to scope the dashboard data.
    .PARAMETER IncludeSnapshots
        Include snapshot metadata in the dashboard.
    .PARAMETER IncludeSnapshotContent
        Export and embed snapshot content for property-level comparison.
        Implies -IncludeSnapshots.
    .EXAMPLE
        New-TBDashboard -OutputPath './dashboard.html'
    .EXAMPLE
        New-TBDashboard -IncludeSnapshots -IncludeSnapshotContent
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter()]
        [string]$OutputPath,

        [Parameter()]
        [string]$MonitorId,

        [Parameter()]
        [switch]$IncludeSnapshots,

        [Parameter()]
        [switch]$IncludeSnapshotContent
    )

    if ($IncludeSnapshotContent) {
        $IncludeSnapshots = [switch]::new($true)
    }

    if (-not $OutputPath) {
        $dateStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $OutputPath = 'TBDashboard-{0}.html' -f $dateStamp
    }

    $driftParams = @{}
    if ($MonitorId) {
        $driftParams['MonitorId'] = $MonitorId
    }

    Write-TBLog -Message 'Collecting data for dashboard'

    $monitors = @(Get-TBMonitor)
    $drifts = @(Get-TBDrift @driftParams)
    $driftSummary = Get-TBDriftSummary @driftParams
    $monitorResults = @(Get-TBMonitorResult)

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

    $snapshots = @()
    $snapshotContents = @()
    if ($IncludeSnapshots) {
        $snapshots = @(Get-TBSnapshot)

        if ($IncludeSnapshotContent) {
            foreach ($snap in $snapshots) {
                $snapStatus = ''
                if ($snap -is [hashtable]) {
                    $snapStatus = $snap['status']
                }
                elseif ($snap.PSObject.Properties['Status']) {
                    $snapStatus = $snap.Status
                }

                if ($snapStatus -eq 'succeeded' -or $snapStatus -eq 'partiallySuccessful') {
                    $snapId = ''
                    if ($snap -is [hashtable]) { $snapId = $snap['id'] }
                    elseif ($snap.PSObject.Properties['Id']) { $snapId = $snap.Id }

                    try {
                        $exported = Export-TBSnapshot -SnapshotId $snapId -OutputPath ([System.IO.Path]::GetTempFileName())
                        if ($exported -and $exported.OutputPath) {
                            $contentJson = Get-Content -Path $exported.OutputPath -Raw
                            $snapshotContents += [PSCustomObject]@{
                                SnapshotId = $snapId
                                Content    = ($contentJson | ConvertFrom-Json)
                            }
                            Remove-Item -Path $exported.OutputPath -Force -ErrorAction SilentlyContinue
                        }
                    }
                    catch {
                        Write-TBLog -Message ('Could not export snapshot {0}: {1}' -f $snapId, $_.Exception.Message) -Level 'Warning'
                    }
                }
            }
        }
    }

    $timestamp = (Get-Date).ToString('o')

    $dashboardData = [PSCustomObject]@{
        GeneratedAt      = $timestamp
        Monitors         = $monitors
        Drifts           = $drifts
        DriftSummary     = $driftSummary
        MonitorResults   = $monitorResults
        Baselines        = $baselines
        Snapshots        = $snapshots
        SnapshotContents = $snapshotContents
    }

    if ($PSCmdlet.ShouldProcess($OutputPath, 'Generate dashboard')) {
        $parentDir = Split-Path -Path $OutputPath -Parent
        if ($parentDir -and -not (Test-Path -Path $parentDir)) {
            $null = New-Item -Path $parentDir -ItemType Directory -Force
        }

        $html = New-TBDashboardHtml -DashboardData $dashboardData
        $html | Out-File -FilePath $OutputPath -Encoding utf8 -Force

        Write-TBLog -Message ('Dashboard generated: {0}' -f $OutputPath)

        [PSCustomObject]@{
            OutputPath    = (Resolve-Path -Path $OutputPath).Path
            MonitorCount  = $monitors.Count
            DriftCount    = $drifts.Count
            SnapshotCount = $snapshots.Count
            GeneratedAt   = $timestamp
        }
    }
}

function New-TBDashboardHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$DashboardData
    )

    $dataJson = $DashboardData | ConvertTo-Json -Depth 20 -Compress
    $styleTokens = Get-TBFluentHtmlStyleTokenSet

    # All dynamic values in the JavaScript use the esc() function which creates
    # a temporary DOM element and sets textContent to safely encode values before
    # inserting them into the page. The data source is the module's own API
    # responses serialized as JSON at generation time, not external user input.

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TenantBaseline Dashboard</title>
    <style>
$styleTokens
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { color: var(--tb-text); }
        .header { background: linear-gradient(135deg, var(--tb-accent) 0%, #204a96 100%); color: #fff; padding: 1rem 2rem; }
        .header h1 { font-size: 1.4rem; font-weight: 600; }
        .header .subtitle { font-size: 0.85rem; opacity: 0.85; margin-top: 0.2rem; }
        .tabs { display: flex; background: var(--tb-surface); border-bottom: 2px solid var(--tb-border); padding: 0 2rem; }
        .tab { padding: 0.75rem 1.5rem; cursor: pointer; border-bottom: 2px solid transparent; margin-bottom: -2px; font-weight: 500; color: var(--tb-text-muted); transition: all 0.15s; }
        .tab:hover { color: var(--tb-accent); }
        .tab.active { color: var(--tb-accent); border-bottom-color: var(--tb-accent); }
        .content { padding: 1.5rem 2rem; max-width: 1400px; }
        .tab-panel { display: none; }
        .tab-panel.active { display: block; }
        .summary-cards { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1.5rem; }
        .card { background: #fff; border: 1px solid #edebe9; border-radius: 4px; padding: 1rem 1.5rem; min-width: 180px; flex: 1; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
        .card .label { font-size: 0.8rem; color: #605e5c; text-transform: uppercase; letter-spacing: 0.5px; }
        .card .value { font-size: 2rem; font-weight: 600; color: #323130; }
        .card.alert .value { color: #d83b01; }
        .card.success .value { color: #107c10; }
        h2 { color: #323130; margin: 1.5rem 0 1rem; font-size: 1.2rem; }
        h3 { color: #605e5c; margin: 1rem 0 0.5rem; font-size: 1rem; }
        table { width: 100%; border-collapse: collapse; background: #fff; margin: 0.5rem 0 1.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
        th { background: #0078d4; color: #fff; text-align: left; padding: 0.6rem 1rem; font-weight: 600; font-size: 0.85rem; }
        td { padding: 0.5rem 1rem; border-bottom: 1px solid #edebe9; font-size: 0.9rem; }
        tr:hover td { background: #f3f2f1; }
        code { background: #f3f2f1; padding: 0.1rem 0.3rem; border-radius: 3px; font-size: 0.85em; }
        .badge { display: inline-block; padding: 0.15rem 0.5rem; border-radius: 3px; font-size: 0.8rem; font-weight: 600; }
        .badge-active { background: #fde7e9; color: #d83b01; }
        .badge-fixed { background: #dff6dd; color: #107c10; }
        .badge-status-active { background: #dff6dd; color: #107c10; }
        .badge-running { background: #fff4ce; color: #797673; }
        .badge-succeeded { background: #dff6dd; color: #107c10; }
        .badge-failed { background: #fde7e9; color: #d83b01; }
        .filter-bar { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1rem; align-items: center; }
        .filter-bar label { font-size: 0.85rem; color: #605e5c; }
        .filter-bar select { padding: 0.4rem 0.6rem; border: 1px solid #edebe9; border-radius: 3px; font-size: 0.85rem; background: #fff; }
        .svg-container { background: #fff; border: 1px solid #edebe9; border-radius: 4px; padding: 1rem; margin: 1rem 0; overflow-x: auto; }
        svg text { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
        .tooltip { position: absolute; background: #323130; color: #fff; padding: 0.4rem 0.8rem; border-radius: 3px; font-size: 0.8rem; pointer-events: none; z-index: 100; white-space: nowrap; display: none; }
        .monitor-card { background: #fff; border: 1px solid #edebe9; border-radius: 4px; padding: 1rem 1.5rem; margin: 0.75rem 0; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
        .monitor-card h3 { margin-top: 0; color: #323130; }
        .monitor-card .meta { font-size: 0.85rem; color: #605e5c; margin: 0.3rem 0; }
        .resource-list { margin: 0.5rem 0; padding-left: 1.5rem; }
        .resource-list li { font-size: 0.85rem; margin: 0.2rem 0; color: #323130; }
        .expandable-header { cursor: pointer; user-select: none; }
        .expandable-header::before { content: '+ '; font-weight: bold; color: #0078d4; }
        .expandable-header.expanded::before { content: '- '; }
        .expandable-content { display: none; }
        .expandable-content.expanded { display: block; }
        .comparison-controls { display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1rem; align-items: flex-end; }
        .comparison-controls .select-group { display: flex; flex-direction: column; gap: 0.3rem; }
        .comparison-controls label { font-size: 0.85rem; color: #605e5c; font-weight: 600; }
        .comparison-controls select { padding: 0.4rem 0.6rem; border: 1px solid #edebe9; border-radius: 3px; font-size: 0.85rem; min-width: 200px; }
        .comparison-controls button { padding: 0.4rem 1rem; background: #0078d4; color: #fff; border: none; border-radius: 3px; cursor: pointer; font-size: 0.85rem; }
        .comparison-controls button:hover { background: #106ebe; }
        .diff-added { background: #dff6dd; }
        .diff-removed { background: #fde7e9; }
        .diff-changed { background: #fff4ce; }
        .no-data { text-align: center; color: #a19f9d; padding: 2rem; font-style: italic; }
        @media print {
            .tabs, .filter-bar, .comparison-controls button { display: none; }
            .tab-panel { display: block !important; page-break-inside: avoid; }
            body { background: #fff; }
            .header { background: #323130; }
        }
        @media (max-width: 768px) {
            .content { padding: 1rem; }
            .tabs { padding: 0 1rem; overflow-x: auto; }
            .summary-cards { flex-direction: column; }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>TenantBaseline Dashboard</h1>
        <div class="subtitle" id="generated-at"></div>
    </div>

    <div class="tabs" id="tab-bar"></div>

    <div class="content">
        <div class="tab-panel active" id="panel-overview">
            <div class="summary-cards" id="summary-cards"></div>
            <h2>Status Breakdown</h2>
            <div class="svg-container" id="status-chart"></div>
            <h2>Resource Type Breakdown</h2>
            <div class="svg-container" id="resource-chart"></div>
        </div>
        <div class="tab-panel" id="panel-timeline">
            <div class="filter-bar" id="filter-bar"></div>
            <div class="svg-container" id="timeline-chart"></div>
            <h2>Drift Details</h2>
            <div id="drift-table-container"></div>
        </div>
        <div class="tab-panel" id="panel-monitors">
            <div id="monitor-cards"></div>
        </div>
        <div class="tab-panel" id="panel-snapshots">
            <div id="snapshot-section"></div>
        </div>
    </div>

    <div class="tooltip" id="tooltip"></div>

    <script id="tb-data" type="application/json">$dataJson</script>
    <script>
    (function() {
        'use strict';

        var dataEl = document.getElementById('tb-data');
        var data = JSON.parse(dataEl.textContent);
        var tooltip = document.getElementById('tooltip');

        // Safe text encoding: creates a temporary element, sets textContent,
        // then reads back the safely-encoded content.
        function esc(str) {
            if (str === null || str === undefined) return '';
            var d = document.createElement('span');
            d.textContent = String(str);
            return d.textContent;
        }

        function prop(obj, name) {
            if (!obj) return '';
            if (typeof obj[name] !== 'undefined') return obj[name];
            var lower = name.charAt(0).toLowerCase() + name.slice(1);
            if (typeof obj[lower] !== 'undefined') return obj[lower];
            return '';
        }

        // DOM helper: creates an element with attributes and children
        function el(tag, attrs, children) {
            var e = document.createElement(tag);
            if (attrs) {
                for (var k in attrs) {
                    if (attrs.hasOwnProperty(k)) {
                        if (k === 'className') e.className = attrs[k];
                        else if (k === 'textContent') e.textContent = attrs[k];
                        else e.setAttribute(k, attrs[k]);
                    }
                }
            }
            if (children) {
                if (typeof children === 'string') e.textContent = children;
                else if (Array.isArray(children)) {
                    for (var i = 0; i < children.length; i++) {
                        if (children[i]) e.appendChild(children[i]);
                    }
                }
            }
            return e;
        }

        function textEl(tag, text, className) {
            var e = document.createElement(tag);
            e.textContent = text;
            if (className) e.className = className;
            return e;
        }

        // Tab setup using DOM methods
        var tabDefs = [
            { id: 'overview', label: 'Overview' },
            { id: 'timeline', label: 'Drift Timeline' },
            { id: 'monitors', label: 'Monitor Details' },
            { id: 'snapshots', label: 'Snapshot Comparison' }
        ];
        var tabBar = document.getElementById('tab-bar');
        var panels = [];
        for (var i = 0; i < tabDefs.length; i++) {
            var tabEl = textEl('div', tabDefs[i].label, 'tab' + (i === 0 ? ' active' : ''));
            tabEl.setAttribute('data-tab', tabDefs[i].id);
            tabBar.appendChild(tabEl);
            panels.push(document.getElementById('panel-' + tabDefs[i].id));
        }

        tabBar.addEventListener('click', function(e) {
            if (!e.target.classList.contains('tab')) return;
            var target = e.target.getAttribute('data-tab');
            var allTabs = tabBar.querySelectorAll('.tab');
            for (var j = 0; j < allTabs.length; j++) allTabs[j].classList.remove('active');
            for (var j = 0; j < panels.length; j++) panels[j].classList.remove('active');
            e.target.classList.add('active');
            document.getElementById('panel-' + target).classList.add('active');
        });

        // Timestamp
        document.getElementById('generated-at').textContent = 'Generated: ' + esc(data.GeneratedAt || data.generatedAt);

        var monitors = data.Monitors || data.monitors || [];
        var drifts = data.Drifts || data.drifts || [];
        var summary = data.DriftSummary || data.driftSummary || {};
        var snapshots = data.Snapshots || data.snapshots || [];
        var monitorResults = data.MonitorResults || data.monitorResults || [];
        var baselines = data.Baselines || data.baselines || [];
        var snapshotContents = data.SnapshotContents || data.snapshotContents || [];

        // Overview: Summary Cards (DOM-based)
        var activeDrifts = 0, fixedDrifts = 0, totalProps = 0;
        for (var i = 0; i < drifts.length; i++) {
            var st = prop(drifts[i], 'Status') || prop(drifts[i], 'status');
            if (st === 'active') activeDrifts++;
            if (st === 'fixed') fixedDrifts++;
            var dp = prop(drifts[i], 'DriftedProperties') || prop(drifts[i], 'driftedProperties');
            if (dp && dp.length) totalProps += dp.length;
        }

        var cardsContainer = document.getElementById('summary-cards');
        var cardDefs = [
            { label: 'Monitors', value: monitors.length, cls: '' },
            { label: 'Active Drifts', value: activeDrifts, cls: activeDrifts > 0 ? ' alert' : '' },
            { label: 'Fixed Drifts', value: fixedDrifts, cls: ' success' },
            { label: 'Drifted Properties', value: totalProps, cls: '' }
        ];
        for (var i = 0; i < cardDefs.length; i++) {
            var card = el('div', { className: 'card' + cardDefs[i].cls }, [
                textEl('div', cardDefs[i].label, 'label'),
                textEl('div', String(cardDefs[i].value), 'value')
            ]);
            cardsContainer.appendChild(card);
        }

        // Overview: Bar charts (SVG is inherently safe as we use createElementNS
        // and textContent for all text nodes)
        function renderBarChart(containerId, dataMap, colorMap) {
            var container = document.getElementById(containerId);
            container.textContent = '';
            var keys = [];
            for (var k in dataMap) {
                if (dataMap.hasOwnProperty(k)) keys.push(k);
            }
            if (keys.length === 0) {
                container.appendChild(textEl('div', 'No data available.', 'no-data'));
                return;
            }
            var maxVal = 0;
            for (var i = 0; i < keys.length; i++) {
                if (dataMap[keys[i]] > maxVal) maxVal = dataMap[keys[i]];
            }
            if (maxVal === 0) maxVal = 1;

            var barHeight = 28, labelWidth = 220, chartWidth = 500;
            var svgHeight = keys.length * (barHeight + 8) + 20;
            var svgWidth = labelWidth + chartWidth + 60;
            var ns = 'http://www.w3.org/2000/svg';
            var svg = document.createElementNS(ns, 'svg');
            svg.setAttribute('width', svgWidth);
            svg.setAttribute('height', svgHeight);

            for (var i = 0; i < keys.length; i++) {
                var y = i * (barHeight + 8) + 10;
                var val = dataMap[keys[i]];
                var barW = Math.max((val / maxVal) * chartWidth, 2);
                var color = (colorMap && colorMap[keys[i]]) || '#0078d4';

                var lbl = document.createElementNS(ns, 'text');
                lbl.setAttribute('x', labelWidth - 8);
                lbl.setAttribute('y', y + barHeight / 2 + 4);
                lbl.setAttribute('text-anchor', 'end');
                lbl.setAttribute('font-size', '12');
                lbl.setAttribute('fill', '#323130');
                lbl.textContent = keys[i];
                svg.appendChild(lbl);

                var rect = document.createElementNS(ns, 'rect');
                rect.setAttribute('x', labelWidth);
                rect.setAttribute('y', y);
                rect.setAttribute('width', barW);
                rect.setAttribute('height', barHeight);
                rect.setAttribute('fill', color);
                rect.setAttribute('rx', '3');
                svg.appendChild(rect);

                var valTxt = document.createElementNS(ns, 'text');
                valTxt.setAttribute('x', labelWidth + barW + 8);
                valTxt.setAttribute('y', y + barHeight / 2 + 4);
                valTxt.setAttribute('font-size', '12');
                valTxt.setAttribute('fill', '#605e5c');
                valTxt.textContent = String(val);
                svg.appendChild(valTxt);
            }
            container.appendChild(svg);
        }

        var statusMap = {};
        var byStatus = prop(summary, 'ByStatus') || prop(summary, 'byStatus');
        if (byStatus) {
            for (var k in byStatus) {
                if (byStatus.hasOwnProperty(k)) statusMap[k] = byStatus[k];
            }
        }
        renderBarChart('status-chart', statusMap, { active: '#d83b01', fixed: '#107c10' });

        var resourceMap = {};
        var byResource = prop(summary, 'ByResourceType') || prop(summary, 'byResourceType');
        if (byResource) {
            for (var k in byResource) {
                if (byResource.hasOwnProperty(k)) resourceMap[k] = byResource[k];
            }
        }
        renderBarChart('resource-chart', resourceMap, {});

        // Timeline Tab: Build filter bar using DOM
        var filterBar = document.getElementById('filter-bar');
        var statusLabel = textEl('label', 'Status:');
        statusLabel.setAttribute('for', 'filter-status');
        var statusSelect = el('select', { id: 'filter-status' });
        var statusOpts = [['all', 'All'], ['active', 'Active'], ['fixed', 'Fixed']];
        for (var i = 0; i < statusOpts.length; i++) {
            var o = el('option', { value: statusOpts[i][0] }, statusOpts[i][1]);
            statusSelect.appendChild(o);
        }
        var statusDiv = el('div', {}, [statusLabel, statusSelect]);
        filterBar.appendChild(statusDiv);

        var rtLabel = textEl('label', 'Resource Type:');
        rtLabel.setAttribute('for', 'filter-resource');
        var rtSelect = el('select', { id: 'filter-resource' });
        rtSelect.appendChild(el('option', { value: 'all' }, 'All'));
        var resourceTypes = {};
        for (var i = 0; i < drifts.length; i++) {
            var rt = prop(drifts[i], 'ResourceType') || prop(drifts[i], 'resourceType') || 'Unknown';
            if (!resourceTypes[rt]) {
                resourceTypes[rt] = true;
                rtSelect.appendChild(el('option', { value: rt }, rt));
            }
        }
        var rtDiv = el('div', {}, [rtLabel, rtSelect]);
        filterBar.appendChild(rtDiv);

        function renderTimeline() {
            var statusFilter = document.getElementById('filter-status').value;
            var rtFilter = document.getElementById('filter-resource').value;

            var filtered = [];
            for (var i = 0; i < drifts.length; i++) {
                var d = drifts[i];
                var st = (prop(d, 'Status') || prop(d, 'status') || '').toLowerCase();
                var rt = prop(d, 'ResourceType') || prop(d, 'resourceType') || 'Unknown';
                if (statusFilter !== 'all' && st !== statusFilter) continue;
                if (rtFilter !== 'all' && rt !== rtFilter) continue;
                filtered.push(d);
            }

            // Build drift table using DOM
            var tableContainer = document.getElementById('drift-table-container');
            tableContainer.textContent = '';

            var table = document.createElement('table');
            var thead = document.createElement('thead');
            var headerRow = document.createElement('tr');
            var headers = ['Resource Type', 'Resource', 'Status', 'First Detected', 'Drifted Properties'];
            for (var h = 0; h < headers.length; h++) {
                headerRow.appendChild(textEl('th', headers[h]));
            }
            thead.appendChild(headerRow);
            table.appendChild(thead);

            var tbody = document.createElement('tbody');
            if (filtered.length === 0) {
                var emptyRow = document.createElement('tr');
                var emptyCell = textEl('td', 'No drifts match the current filters.', 'no-data');
                emptyCell.setAttribute('colspan', '5');
                emptyRow.appendChild(emptyCell);
                tbody.appendChild(emptyRow);
            } else {
                for (var i = 0; i < filtered.length; i++) {
                    var d = filtered[i];
                    var row = document.createElement('tr');
                    row.appendChild(textEl('td', prop(d, 'ResourceType') || prop(d, 'resourceType') || ''));
                    row.appendChild(textEl('td', prop(d, 'BaselineResourceDisplayName') || prop(d, 'baselineResourceDisplayName') || ''));

                    var stVal = prop(d, 'Status') || prop(d, 'status') || '';
                    var stCell = document.createElement('td');
                    stCell.appendChild(textEl('span', stVal, 'badge ' + (stVal === 'active' ? 'badge-active' : 'badge-fixed')));
                    row.appendChild(stCell);

                    row.appendChild(textEl('td', String(prop(d, 'FirstReportedDateTime') || prop(d, 'firstReportedDateTime') || '')));

                    var dpArr = prop(d, 'DriftedProperties') || prop(d, 'driftedProperties') || [];
                    var propsText = [];
                    for (var j = 0; j < dpArr.length; j++) {
                        propsText.push(prop(dpArr[j], 'propertyName') || prop(dpArr[j], 'PropertyName') || '');
                    }
                    row.appendChild(textEl('td', propsText.join(', ')));
                    tbody.appendChild(row);
                }
            }
            table.appendChild(tbody);
            tableContainer.appendChild(table);

            // SVG Timeline using DOM
            var timelineContainer = document.getElementById('timeline-chart');
            timelineContainer.textContent = '';

            if (filtered.length === 0) {
                timelineContainer.appendChild(textEl('div', 'No drifts to display on timeline.', 'no-data'));
                return;
            }

            var dates = [];
            var rtList = [];
            var rtSet = {};
            for (var i = 0; i < filtered.length; i++) {
                var dtStr = prop(filtered[i], 'FirstReportedDateTime') || prop(filtered[i], 'firstReportedDateTime') || '';
                if (dtStr) {
                    var dateObj = new Date(dtStr);
                    if (!isNaN(dateObj.getTime())) dates.push(dateObj);
                }
                var rt = prop(filtered[i], 'ResourceType') || prop(filtered[i], 'resourceType') || 'Unknown';
                if (!rtSet[rt]) { rtSet[rt] = true; rtList.push(rt); }
            }

            if (dates.length === 0) {
                timelineContainer.appendChild(textEl('div', 'No valid dates for timeline.', 'no-data'));
                return;
            }

            var minDate = dates[0], maxDate = dates[0];
            for (var i = 1; i < dates.length; i++) {
                if (dates[i] < minDate) minDate = dates[i];
                if (dates[i] > maxDate) maxDate = dates[i];
            }

            var leftMargin = 240, rightMargin = 40, topMargin = 30, rowHeight = 36, chartWidth = 600;
            var svgWidth = leftMargin + chartWidth + rightMargin;
            var svgHeight = topMargin + rtList.length * rowHeight + 40;
            var dateRange = maxDate.getTime() - minDate.getTime();
            if (dateRange === 0) dateRange = 86400000;
            var ns = 'http://www.w3.org/2000/svg';

            var svg = document.createElementNS(ns, 'svg');
            svg.setAttribute('width', svgWidth);
            svg.setAttribute('height', svgHeight);

            // Y-axis labels and grid lines
            for (var i = 0; i < rtList.length; i++) {
                var y = topMargin + i * rowHeight + rowHeight / 2;
                var lbl = document.createElementNS(ns, 'text');
                lbl.setAttribute('x', leftMargin - 8);
                lbl.setAttribute('y', y + 4);
                lbl.setAttribute('text-anchor', 'end');
                lbl.setAttribute('font-size', '11');
                lbl.setAttribute('fill', '#323130');
                lbl.textContent = rtList[i];
                svg.appendChild(lbl);

                var line = document.createElementNS(ns, 'line');
                line.setAttribute('x1', leftMargin);
                line.setAttribute('y1', y);
                line.setAttribute('x2', leftMargin + chartWidth);
                line.setAttribute('y2', y);
                line.setAttribute('stroke', '#edebe9');
                line.setAttribute('stroke-width', '1');
                svg.appendChild(line);
            }

            // X-axis date labels
            var numLabels = Math.min(5, filtered.length);
            for (var i = 0; i <= numLabels; i++) {
                var t = minDate.getTime() + (dateRange * i / numLabels);
                var d = new Date(t);
                var label = d.toISOString().substring(0, 10);
                var x = leftMargin + (chartWidth * i / numLabels);
                var dtLbl = document.createElementNS(ns, 'text');
                dtLbl.setAttribute('x', x);
                dtLbl.setAttribute('y', svgHeight - 5);
                dtLbl.setAttribute('text-anchor', 'middle');
                dtLbl.setAttribute('font-size', '10');
                dtLbl.setAttribute('fill', '#a19f9d');
                dtLbl.textContent = label;
                svg.appendChild(dtLbl);
            }

            // Drift circles
            for (var i = 0; i < filtered.length; i++) {
                var d = filtered[i];
                var dtStr = prop(d, 'FirstReportedDateTime') || prop(d, 'firstReportedDateTime') || '';
                var dateObj = new Date(dtStr);
                if (isNaN(dateObj.getTime())) continue;

                var rt = prop(d, 'ResourceType') || prop(d, 'resourceType') || 'Unknown';
                var st = (prop(d, 'Status') || prop(d, 'status') || '').toLowerCase();
                var rn = prop(d, 'BaselineResourceDisplayName') || prop(d, 'baselineResourceDisplayName') || '';
                var rtIdx = rtList.indexOf(rt);
                var cx = leftMargin + ((dateObj.getTime() - minDate.getTime()) / dateRange) * chartWidth;
                var cy = topMargin + rtIdx * rowHeight + rowHeight / 2;
                var color = st === 'active' ? '#d83b01' : '#107c10';

                var circle = document.createElementNS(ns, 'circle');
                circle.setAttribute('cx', cx);
                circle.setAttribute('cy', cy);
                circle.setAttribute('r', '7');
                circle.setAttribute('fill', color);
                circle.setAttribute('stroke', '#fff');
                circle.setAttribute('stroke-width', '2');
                circle.style.cursor = 'pointer';

                // Store tooltip data as a data attribute
                var tipText = rn + ' (' + st + ') - ' + dtStr;
                circle.setAttribute('data-tip', tipText);

                circle.addEventListener('mouseenter', function(e) {
                    tooltip.textContent = this.getAttribute('data-tip');
                    tooltip.style.display = 'block';
                    tooltip.style.left = (e.pageX + 12) + 'px';
                    tooltip.style.top = (e.pageY - 8) + 'px';
                });
                circle.addEventListener('mouseleave', function() {
                    tooltip.style.display = 'none';
                });
                svg.appendChild(circle);
            }

            timelineContainer.appendChild(svg);
        }

        statusSelect.addEventListener('change', renderTimeline);
        rtSelect.addEventListener('change', renderTimeline);
        renderTimeline();

        // Monitor Details Tab (DOM-based)
        var monitorCardsEl = document.getElementById('monitor-cards');
        if (monitors.length === 0) {
            monitorCardsEl.appendChild(textEl('div', 'No monitors configured.', 'no-data'));
        } else {
            for (var i = 0; i < monitors.length; i++) {
                var m = monitors[i];
                var mId = prop(m, 'Id') || prop(m, 'id');
                var mName = prop(m, 'DisplayName') || prop(m, 'displayName') || '';
                var mDesc = prop(m, 'Description') || prop(m, 'description') || '';
                var mStatus = prop(m, 'Status') || prop(m, 'status') || '';
                var mFreq = prop(m, 'MonitorRunFrequencyInHours') || prop(m, 'monitorRunFrequencyInHours') || '-';

                var card = el('div', { className: 'monitor-card' });

                var titleEl = document.createElement('h3');
                titleEl.textContent = mName + ' ';
                var badge = textEl('span', mStatus, 'badge badge-status-active');
                titleEl.appendChild(badge);
                card.appendChild(titleEl);

                card.appendChild(textEl('div', mDesc, 'meta'));
                card.appendChild(textEl('div', 'Frequency: every ' + mFreq + 'h | ID: ' + mId, 'meta'));

                // Last run result
                for (var j = 0; j < monitorResults.length; j++) {
                    var rMid = prop(monitorResults[j], 'MonitorId') || prop(monitorResults[j], 'monitorId');
                    if (rMid === mId) {
                        var runStatus = prop(monitorResults[j], 'RunStatus') || prop(monitorResults[j], 'runStatus') || '-';
                        var driftsCnt = prop(monitorResults[j], 'DriftsCount') || prop(monitorResults[j], 'driftsCount') || 0;
                        var runStart = String(prop(monitorResults[j], 'RunInitiationDateTime') || prop(monitorResults[j], 'runInitiationDateTime') || '');
                        var rsBadge = 'badge-running';
                        if (runStatus === 'successful') rsBadge = 'badge-succeeded';
                        else if (runStatus === 'failed') rsBadge = 'badge-failed';

                        var resultDiv = el('div', { className: 'meta' });
                        resultDiv.textContent = 'Last Run: ';
                        resultDiv.appendChild(textEl('span', runStatus, 'badge ' + rsBadge));
                        var runMeta = document.createTextNode(' | Drifts: ' + driftsCnt + ' | ' + runStart);
                        resultDiv.appendChild(runMeta);
                        card.appendChild(resultDiv);
                        break;
                    }
                }

                // Baseline resources
                for (var j = 0; j < baselines.length; j++) {
                    var bl = baselines[j];
                    var resources = prop(bl, 'Resources') || prop(bl, 'resources') || [];
                    if (resources.length > 0) {
                        var expHeader = textEl('div', 'Baseline Resources (' + resources.length + ')', 'expandable-header');
                        expHeader.addEventListener('click', function() {
                            this.classList.toggle('expanded');
                            var content = this.nextElementSibling;
                            if (content) content.classList.toggle('expanded');
                        });
                        card.appendChild(expHeader);

                        var expContent = el('div', { className: 'expandable-content' });
                        var ul = document.createElement('ul');
                        ul.className = 'resource-list';
                        for (var k = 0; k < resources.length; k++) {
                            var resName = prop(resources[k], 'displayName') || prop(resources[k], 'DisplayName') || '';
                            var resType = prop(resources[k], 'resourceType') || prop(resources[k], 'ResourceType') || '';
                            var li = document.createElement('li');
                            li.appendChild(textEl('strong', resName));
                            li.appendChild(document.createTextNode(' (' + resType + ')'));
                            ul.appendChild(li);
                        }
                        expContent.appendChild(ul);
                        card.appendChild(expContent);
                        break;
                    }
                }

                monitorCardsEl.appendChild(card);
            }
        }

        // Snapshot Comparison Tab (DOM-based)
        var snapshotSection = document.getElementById('snapshot-section');

        if (snapshots.length === 0) {
            snapshotSection.appendChild(textEl('div', 'No snapshots included. Use -IncludeSnapshots when generating the dashboard.', 'no-data'));
        } else {
            var controls = el('div', { className: 'comparison-controls' });

            var groupA = el('div', { className: 'select-group' });
            groupA.appendChild(textEl('label', 'Snapshot A:'));
            var selectA = el('select', { id: 'snap-a' });
            for (var i = 0; i < snapshots.length; i++) {
                var sName = prop(snapshots[i], 'DisplayName') || prop(snapshots[i], 'displayName') || '';
                var sId = prop(snapshots[i], 'Id') || prop(snapshots[i], 'id') || '';
                selectA.appendChild(el('option', { value: sId }, sName));
            }
            groupA.appendChild(selectA);
            controls.appendChild(groupA);

            var groupB = el('div', { className: 'select-group' });
            groupB.appendChild(textEl('label', 'Snapshot B:'));
            var selectB = el('select', { id: 'snap-b' });
            for (var i = 0; i < snapshots.length; i++) {
                var sName = prop(snapshots[i], 'DisplayName') || prop(snapshots[i], 'displayName') || '';
                var sId = prop(snapshots[i], 'Id') || prop(snapshots[i], 'id') || '';
                var opt = el('option', { value: sId }, sName);
                if (i === 1) opt.selected = true;
                selectB.appendChild(opt);
            }
            groupB.appendChild(selectB);
            controls.appendChild(groupB);

            var compareBtn = textEl('button', 'Compare');
            compareBtn.addEventListener('click', doCompare);
            controls.appendChild(compareBtn);

            snapshotSection.appendChild(controls);
            var resultContainer = el('div', { id: 'comparison-result' });
            snapshotSection.appendChild(resultContainer);
        }

        function doCompare() {
            var aId = document.getElementById('snap-a').value;
            var bId = document.getElementById('snap-b').value;
            var resultEl = document.getElementById('comparison-result');
            resultEl.textContent = '';

            var snapA = null, snapB = null;
            for (var i = 0; i < snapshots.length; i++) {
                var id = prop(snapshots[i], 'Id') || prop(snapshots[i], 'id');
                if (id === aId) snapA = snapshots[i];
                if (id === bId) snapB = snapshots[i];
            }

            if (!snapA || !snapB) {
                resultEl.appendChild(textEl('div', 'Select two snapshots to compare.', 'no-data'));
                return;
            }

            var resA = prop(snapA, 'Resources') || prop(snapA, 'resources') || [];
            var resB = prop(snapB, 'Resources') || prop(snapB, 'resources') || [];
            var setA = {}, setB = {};
            for (var i = 0; i < resA.length; i++) setA[resA[i]] = true;
            for (var i = 0; i < resB.length; i++) setB[resB[i]] = true;

            resultEl.appendChild(textEl('h2', 'Resource Coverage Comparison'));

            var table = document.createElement('table');
            table.className = 'diff-table';
            var thead = document.createElement('thead');
            var hRow = document.createElement('tr');
            hRow.appendChild(textEl('th', 'Resource Type'));
            hRow.appendChild(textEl('th', 'Snapshot A'));
            hRow.appendChild(textEl('th', 'Snapshot B'));
            thead.appendChild(hRow);
            table.appendChild(thead);

            var tbody = document.createElement('tbody');
            var allRes = {};
            for (var r in setA) allRes[r] = true;
            for (var r in setB) allRes[r] = true;
            var allKeys = [];
            for (var r in allRes) allKeys.push(r);
            allKeys.sort();

            for (var i = 0; i < allKeys.length; i++) {
                var r = allKeys[i];
                var inA = !!setA[r], inB = !!setB[r];
                var row = document.createElement('tr');
                if (inA && !inB) row.className = 'diff-removed';
                else if (!inA && inB) row.className = 'diff-added';
                row.appendChild(textEl('td', r));
                row.appendChild(textEl('td', inA ? 'Yes' : '-'));
                row.appendChild(textEl('td', inB ? 'Yes' : '-'));
                tbody.appendChild(row);
            }
            table.appendChild(tbody);
            resultEl.appendChild(table);

            // Property-level diff
            var contentA = null, contentB = null;
            for (var i = 0; i < snapshotContents.length; i++) {
                var scId = prop(snapshotContents[i], 'SnapshotId') || prop(snapshotContents[i], 'snapshotId');
                if (scId === aId) contentA = prop(snapshotContents[i], 'Content') || prop(snapshotContents[i], 'content');
                if (scId === bId) contentB = prop(snapshotContents[i], 'Content') || prop(snapshotContents[i], 'content');
            }

            if (contentA && contentB) {
                resultEl.appendChild(textEl('h2', 'Property-Level Differences'));
                var diffTable = document.createElement('table');
                diffTable.className = 'diff-table';
                var dThead = document.createElement('thead');
                var dHRow = document.createElement('tr');
                dHRow.appendChild(textEl('th', 'Resource Type'));
                dHRow.appendChild(textEl('th', 'Property'));
                dHRow.appendChild(textEl('th', 'Snapshot A'));
                dHRow.appendChild(textEl('th', 'Snapshot B'));
                dThead.appendChild(dHRow);
                diffTable.appendChild(dThead);

                var dTbody = document.createElement('tbody');
                var hasDiffs = false;

                for (var i = 0; i < allKeys.length; i++) {
                    var r = allKeys[i];
                    if (!setA[r] || !setB[r]) continue;
                    var propsA = findResourceProps(contentA, r);
                    var propsB = findResourceProps(contentB, r);
                    if (!propsA && !propsB) continue;
                    var allPropNames = {};
                    if (propsA) { for (var p in propsA) allPropNames[p] = true; }
                    if (propsB) { for (var p in propsB) allPropNames[p] = true; }
                    for (var p in allPropNames) {
                        var vA = propsA ? (propsA[p] !== undefined ? String(propsA[p]) : '-') : '-';
                        var vB = propsB ? (propsB[p] !== undefined ? String(propsB[p]) : '-') : '-';
                        if (vA !== vB) {
                            hasDiffs = true;
                            var cls = (vA === '-') ? 'diff-added' : (vB === '-') ? 'diff-removed' : 'diff-changed';
                            var dRow = el('tr', { className: cls });
                            dRow.appendChild(textEl('td', r));
                            dRow.appendChild(textEl('td', p));

                            var cA = document.createElement('td');
                            cA.appendChild(textEl('code', vA));
                            dRow.appendChild(cA);

                            var cB = document.createElement('td');
                            cB.appendChild(textEl('code', vB));
                            dRow.appendChild(cB);

                            dTbody.appendChild(dRow);
                        }
                    }
                }

                if (!hasDiffs) {
                    var noDiffRow = document.createElement('tr');
                    var noDiffCell = textEl('td', 'No property differences found.', 'no-data');
                    noDiffCell.setAttribute('colspan', '4');
                    noDiffRow.appendChild(noDiffCell);
                    dTbody.appendChild(noDiffRow);
                }
                diffTable.appendChild(dTbody);
                resultEl.appendChild(diffTable);
            }
        }

        function findResourceProps(content, resourceType) {
            if (!content) return null;
            var resources = prop(content, 'Resources') || prop(content, 'resources') || prop(content, 'Content') || prop(content, 'content');
            if (resources && resources.Resources) resources = resources.Resources;
            if (resources && resources.resources) resources = resources.resources;
            if (!Array.isArray(resources)) return null;
            for (var i = 0; i < resources.length; i++) {
                var rt = prop(resources[i], 'resourceType') || prop(resources[i], 'ResourceType');
                if (rt === resourceType) {
                    return prop(resources[i], 'properties') || prop(resources[i], 'Properties') || {};
                }
            }
            return null;
        }
    })();
    </script>
</body>
</html>
"@

    return $html
}
