function Send-TBDriftNotification {
    <#
    .SYNOPSIS
        Sends webhook notifications for newly detected configuration drift.
    .DESCRIPTION
        Checks the latest UTCM monitor result for one or more monitors and sends
        a webhook notification only when the active drift set for a monitor has
        changed since the last successful notification. This cmdlet is designed
        for unattended execution from runbooks, scheduled jobs, or CI/CD
        runners.
    .PARAMETER MonitorId
        Optional monitor IDs to scope notification checks. When omitted, all
        monitors are evaluated.
    .PARAMETER WebhookUrl
        The HTTPS webhook endpoint that receives the notification payload.
    .PARAMETER PayloadFormat
        Notification payload format:
        - TeamsAdaptiveCard: message payload suitable for Teams workflow/incoming webhook style endpoints
        - Generic: plain JSON payload for automation endpoints such as Logic Apps or custom services
    .PARAMETER StatePath
        Path to the JSON file used to suppress duplicate notifications for the
        same monitor result. Defaults to a per-user local state file.
    .PARAMETER MaxDrifts
        Maximum number of drift entries to include in the payload.
    .PARAMETER Force
        Sends the notification even if the latest monitor result was already
        recorded in the state file.
    .EXAMPLE
        Send-TBDriftNotification -WebhookUrl $env:TB_WEBHOOK_URL
    .EXAMPLE
        Send-TBDriftNotification -MonitorId $monitor.Id -WebhookUrl $env:TB_WEBHOOK_URL -StatePath './tb-notify-state.json'
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string[]]$MonitorId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WebhookUrl,

        [Parameter()]
        [ValidateSet('TeamsAdaptiveCard', 'Generic')]
        [string]$PayloadFormat = 'TeamsAdaptiveCard',

        [Parameter()]
        [string]$StatePath = (Get-TBDefaultNotificationStatePath),

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]$MaxDrifts = 10,

        [Parameter()]
        [switch]$Force
    )

    begin {
        $monitorQueue = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($id in @($MonitorId)) {
            if ($id -and -not $monitorQueue.Contains($id)) {
                $monitorQueue.Add($id)
            }
        }
    }

    end {
        $state = Get-TBNotificationState -Path $StatePath
        $targetLabel = Get-TBWebhookTargetLabel -Uri $WebhookUrl

        $monitors = if ($monitorQueue.Count -gt 0) {
            foreach ($id in $monitorQueue) {
                Get-TBMonitor -MonitorId $id
            }
        }
        else {
            @(Get-TBMonitor)
        }

        foreach ($monitor in @($monitors)) {
            $monitorName = if ($monitor.DisplayName) { $monitor.DisplayName } else { $monitor.Id }
            Write-TBLog -Message ('Evaluating drift notification state for monitor {0} ({1})' -f $monitorName, $monitor.Id)

            $latestResult = @(Get-TBMonitorResult -MonitorId $monitor.Id |
                Sort-Object -Property @{ Expression = {
                        if ($_.RunCompletionDateTime) {
                            [datetimeoffset]$_.RunCompletionDateTime
                        }
                        else {
                            [datetimeoffset]::MinValue
                        }
                    }
                } -Descending |
                Select-Object -First 1)

            if (-not $latestResult) {
                [PSCustomObject]@{
                    MonitorId          = $monitor.Id
                    MonitorDisplayName = $monitor.DisplayName
                    LatestResultId     = $null
                    DriftCount         = 0
                    ActiveDriftCount   = 0
                    NotificationSent   = $false
                    Duplicate          = $false
                    Reason             = 'NoResults'
                    StatePath          = $StatePath
                    PayloadFormat      = $PayloadFormat
                }
                continue
            }

            if ($latestResult.RunStatus -ne 'successful') {
                [PSCustomObject]@{
                    MonitorId          = $monitor.Id
                    MonitorDisplayName = $monitor.DisplayName
                    LatestResultId     = $latestResult.Id
                    DriftCount         = $latestResult.DriftsCount
                    ActiveDriftCount   = 0
                    NotificationSent   = $false
                    Duplicate          = $false
                    Reason             = 'LatestRunNotSuccessful'
                    StatePath          = $StatePath
                    PayloadFormat      = $PayloadFormat
                }
                continue
            }

            $stateItem = $state.Items[$monitor.Id]
            if ([int]$latestResult.DriftsCount -le 0) {
                [PSCustomObject]@{
                    MonitorId          = $monitor.Id
                    MonitorDisplayName = $monitor.DisplayName
                    LatestResultId     = $latestResult.Id
                    DriftCount         = $latestResult.DriftsCount
                    ActiveDriftCount   = 0
                    NotificationSent   = $false
                    Duplicate          = $false
                    Reason             = 'NoDrift'
                    StatePath          = $StatePath
                    PayloadFormat      = $PayloadFormat
                }
                continue
            }

            $drifts = @(Get-TBDrift -MonitorId $monitor.Id)
            $activeDrifts = @($drifts | Where-Object { $_.Status -eq 'active' })
            if ($activeDrifts.Count -le 0) {
                [PSCustomObject]@{
                    MonitorId          = $monitor.Id
                    MonitorDisplayName = $monitor.DisplayName
                    LatestResultId     = $latestResult.Id
                    DriftCount         = $latestResult.DriftsCount
                    ActiveDriftCount   = 0
                    NotificationSent   = $false
                    Duplicate          = $false
                    Reason             = 'NoActiveDrift'
                    StatePath          = $StatePath
                    PayloadFormat      = $PayloadFormat
                }
                continue
            }

            $activeDriftFingerprint = Get-TBActiveDriftFingerprint -Drifts $activeDrifts
            $isDuplicate = (
                -not $Force -and
                $stateItem -and
                $stateItem.LastActiveDriftFingerprint -and
                $stateItem.LastActiveDriftFingerprint -eq $activeDriftFingerprint
            )

            if ($isDuplicate) {
                Write-TBLog -Message ('Skipping notification for monitor {0}; active drift set has not changed since the previous notification' -f $monitorName)
                [PSCustomObject]@{
                    MonitorId          = $monitor.Id
                    MonitorDisplayName = $monitor.DisplayName
                    LatestResultId     = $latestResult.Id
                    DriftCount         = $latestResult.DriftsCount
                    ActiveDriftCount   = $activeDrifts.Count
                    NotificationSent   = $false
                    Duplicate          = $true
                    Reason             = 'AlreadyNotified'
                    StatePath          = $StatePath
                    PayloadFormat      = $PayloadFormat
                }
                continue
            }

            $payload = New-TBDriftNotificationPayload -Monitor $monitor -LatestResult $latestResult -Drifts $drifts -ActiveDrifts $activeDrifts -PayloadFormat $PayloadFormat -MaxDrifts $MaxDrifts

            if ($PSCmdlet.ShouldProcess($targetLabel, ('Send drift notification for monitor {0}' -f $monitorName))) {
                Invoke-TBWebhookRequest -Uri $WebhookUrl -Payload $payload

                $state.Items[$monitor.Id] = @{
                    LastNotifiedResultId       = $latestResult.Id
                    LastRunCompletionDateTime  = $latestResult.RunCompletionDateTime
                    LastNotifiedAt             = (Get-Date).ToString('o')
                    LastPayloadFormat          = $PayloadFormat
                    LastActiveDriftFingerprint = $activeDriftFingerprint
                    LastActiveDriftCount       = $activeDrifts.Count
                }

                Save-TBNotificationState -Path $StatePath -State $state

                [PSCustomObject]@{
                    MonitorId          = $monitor.Id
                    MonitorDisplayName = $monitor.DisplayName
                    LatestResultId     = $latestResult.Id
                    DriftCount         = $latestResult.DriftsCount
                    ActiveDriftCount   = $activeDrifts.Count
                    NotificationSent   = $true
                    Duplicate          = $false
                    Reason             = 'Sent'
                    StatePath          = $StatePath
                    PayloadFormat      = $PayloadFormat
                }
            }
        }
    }
}

function Get-TBDefaultNotificationStatePath {
    [CmdletBinding()]
    param()

    $basePath = $env:LOCALAPPDATA
    if (-not $basePath) {
        $basePath = $env:HOME
    }
    if (-not $basePath) {
        $basePath = [System.IO.Path]::GetTempPath()
    }

    return (Join-Path $basePath 'TenantBaseline/notification-state.json')
}

function Get-TBNotificationState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        return @{
            Version = 1
            Items   = @{}
        }
    }

    try {
        $raw = Get-Content -Path $Path -Raw -ErrorAction Stop
        if (-not $raw.Trim()) {
            return @{
                Version = 1
                Items   = @{}
            }
        }

        $parsed = ConvertFrom-Json -InputObject $raw -AsHashtable -Depth 20
        if (-not $parsed) {
            throw 'Notification state file is empty or invalid.'
        }

        if (-not $parsed.ContainsKey('Items') -or -not $parsed['Items']) {
            $parsed['Items'] = @{}
        }

        return $parsed
    }
    catch {
        Write-TBLog -Message ('Failed to read notification state from {0}: {1}' -f $Path, $_.Exception.Message) -Level 'Warning'
        return @{
            Version = 1
            Items   = @{}
        }
    }
}

function Save-TBNotificationState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    $parentDir = Split-Path -Path $Path -Parent
    if ($parentDir -and -not (Test-Path -Path $parentDir)) {
        $null = New-Item -Path $parentDir -ItemType Directory -Force
    }

    $State | ConvertTo-Json -Depth 20 | Out-File -FilePath $Path -Encoding utf8 -Force
}

function New-TBDriftNotificationPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Monitor,

        [Parameter(Mandatory = $true)]
        [object]$LatestResult,

        [Parameter(Mandatory = $true)]
        [object[]]$Drifts,

        [Parameter(Mandatory = $true)]
        [object[]]$ActiveDrifts,

        [Parameter(Mandatory = $true)]
        [ValidateSet('TeamsAdaptiveCard', 'Generic')]
        [string]$PayloadFormat,

        [Parameter(Mandatory = $true)]
        [int]$MaxDrifts
    )

    $displayDrifts = @($ActiveDrifts | Select-Object -First $MaxDrifts)
    if ($displayDrifts.Count -eq 0) {
        $displayDrifts = @($Drifts | Select-Object -First $MaxDrifts)
    }

    $activeDriftCount = $ActiveDrifts.Count
    $fixedDriftCount = @($Drifts | Where-Object { $_.Status -eq 'fixed' }).Count
    $totalDriftedProperties = 0
    foreach ($drift in $Drifts) {
        $totalDriftedProperties += @($drift.DriftedProperties).Count
    }

    $summaryLine = '{0} active drift{1} detected for monitor "{2}"' -f $activeDriftCount, $(if ($activeDriftCount -eq 1) { '' } else { 's' }), $(if ($Monitor.DisplayName) { $Monitor.DisplayName } else { $Monitor.Id })
    if ($activeDriftCount -eq 0) {
        $summaryLine = '{0} drift result{1} detected for monitor "{2}"' -f $LatestResult.DriftsCount, $(if ([int]$LatestResult.DriftsCount -eq 1) { '' } else { 's' }), $(if ($Monitor.DisplayName) { $Monitor.DisplayName } else { $Monitor.Id })
    }

    $driftItems = foreach ($drift in $displayDrifts) {
        [PSCustomObject]@{
            Id                          = $drift.Id
            Status                      = $drift.Status
            ResourceType                = $drift.ResourceType
            BaselineResourceDisplayName = $drift.BaselineResourceDisplayName
            ResourceInstance            = Get-TBDriftInstanceLabel -Drift $drift
            FirstReportedDateTime       = $drift.FirstReportedDateTime
            DriftedProperties           = @($drift.DriftedProperties | ForEach-Object {
                    [PSCustomObject]@{
                        PropertyName = if ($_.PSObject.Properties['propertyName']) { $_.propertyName } else { $_['propertyName'] }
                        DesiredValue = if ($_.PSObject.Properties['desiredValue']) { "$($_.desiredValue)" } else { "$($_['desiredValue'])" }
                        CurrentValue = if ($_.PSObject.Properties['currentValue']) { "$($_.currentValue)" } else { "$($_['currentValue'])" }
                    }
                })
        }
    }

    $genericPayload = [ordered]@{
        Text        = $summaryLine
        GeneratedAt = (Get-Date).ToString('o')
        TenantId    = $LatestResult.TenantId
        Monitor     = [ordered]@{
            Id          = $Monitor.Id
            DisplayName = $Monitor.DisplayName
            Status      = $Monitor.Status
            Mode        = $Monitor.Mode
        }
        Result      = [ordered]@{
            Id                    = $LatestResult.Id
            RunStatus             = $LatestResult.RunStatus
            RunCompletionDateTime = $LatestResult.RunCompletionDateTime
            DriftsCount           = $LatestResult.DriftsCount
        }
        Summary     = [ordered]@{
            TotalDrifts            = $Drifts.Count
            ActiveDrifts           = $activeDriftCount
            FixedDrifts            = $fixedDriftCount
            TotalDriftedProperties = $totalDriftedProperties
        }
        Drifts      = $driftItems
    }

    if ($PayloadFormat -eq 'Generic') {
        return $genericPayload
    }

    $factSet = @(
        @{ title = 'Monitor'; value = $(if ($Monitor.DisplayName) { $Monitor.DisplayName } else { $Monitor.Id }) }
        @{ title = 'Latest Run'; value = "$($LatestResult.RunCompletionDateTime)" }
        @{ title = 'Active Drifts'; value = "$activeDriftCount" }
        @{ title = 'Total Drifted Properties'; value = "$totalDriftedProperties" }
    )

    $driftBlocks = @()
    foreach ($drift in $driftItems) {
        $propPreview = @($drift.DriftedProperties | Select-Object -First 3 | ForEach-Object {
                '{0}: desired={1}, current={2}' -f $_.PropertyName, $_.DesiredValue, $_.CurrentValue
            }) -join "`n"

        $driftBlocks += @{
            type   = 'TextBlock'
            wrap   = $true
            spacing = 'Medium'
            text   = ('{0} | {1} | {2}{3}' -f $drift.ResourceType, $drift.ResourceInstance, $drift.Status, $(if ($propPreview) { "`n$propPreview" } else { '' }))
        }
    }

    return @{
        type        = 'message'
        attachments = @(
            @{
                contentType = 'application/vnd.microsoft.card.adaptive'
                contentUrl  = $null
                content     = @{
                    '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
                    type      = 'AdaptiveCard'
                    version   = '1.4'
                    body      = @(
                        @{
                            type   = 'TextBlock'
                            size   = 'Large'
                            weight = 'Bolder'
                            text   = 'TenantBaseline Drift Alert'
                        },
                        @{
                            type = 'TextBlock'
                            wrap = $true
                            text = $summaryLine
                        },
                        @{
                            type  = 'FactSet'
                            facts = $factSet
                        }
                    ) + $driftBlocks
                }
            }
        )
    }
}

function Get-TBActiveDriftFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Drifts
    )

    $normalized = foreach ($drift in @($Drifts | Sort-Object -Property ResourceType, BaselineResourceDisplayName, FirstReportedDateTime, Id)) {
        $properties = foreach ($prop in @($drift.DriftedProperties | Sort-Object -Property @{
                    Expression = {
                        if ($_.PSObject.Properties['propertyName']) {
                            $_.propertyName
                        }
                        else {
                            $_['propertyName']
                        }
                    }
                })) {
            [ordered]@{
                PropertyName = if ($prop.PSObject.Properties['propertyName']) { $prop.propertyName } else { $prop['propertyName'] }
                DesiredValue = if ($prop.PSObject.Properties['desiredValue']) { "$($prop.desiredValue)" } else { "$($prop['desiredValue'])" }
                CurrentValue = if ($prop.PSObject.Properties['currentValue']) { "$($prop.currentValue)" } else { "$($prop['currentValue'])" }
            }
        }

        [ordered]@{
            Status           = $drift.Status
            ResourceType     = $drift.ResourceType
            BaselineName     = $drift.BaselineResourceDisplayName
            ResourceInstance = Get-TBDriftInstanceLabel -Drift $drift
            Properties       = @($properties)
        }
    }

    $json = $normalized | ConvertTo-Json -Depth 20 -Compress
    $hashBytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($json))
    return ([Convert]::ToHexString($hashBytes)).ToLowerInvariant()
}

function Get-TBDriftInstanceLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Drift
    )

    $identifier = $Drift.ResourceInstanceIdentifier
    if (-not $identifier) {
        return 'Unknown'
    }

    if ($identifier -is [hashtable]) {
        if ($identifier.ContainsKey('Identity') -and $identifier['Identity']) {
            return "$($identifier['Identity'])"
        }

        return ($identifier | ConvertTo-Json -Depth 5 -Compress)
    }

    if ($identifier.PSObject.Properties['Identity'] -and $identifier.Identity) {
        return "$($identifier.Identity)"
    }

    return ($identifier | ConvertTo-Json -Depth 5 -Compress)
}

function Get-TBWebhookTargetLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    try {
        return ([uri]$Uri).Host
    }
    catch {
        return 'webhook endpoint'
    }
}

function Invoke-TBWebhookRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [object]$Payload,

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$MaxRetries = 3
    )

    $body = $Payload | ConvertTo-Json -Depth 20
    $targetLabel = Get-TBWebhookTargetLabel -Uri $Uri
    $attempt = 0

    while ($true) {
        $attempt++
        Write-TBLog -Message ('Posting drift notification to {0} (attempt {1})' -f $targetLabel, $attempt)

        try {
            return Invoke-RestMethod -Uri $Uri -Method Post -Body $body -ContentType 'application/json'
        }
        catch {
            if ($attempt -ge $MaxRetries) {
                Write-TBLog -Message ('Webhook notification failed after {0} attempts: {1}' -f $attempt, $_.Exception.Message) -Level 'Error'
                throw
            }

            $delaySeconds = [math]::Pow(2, $attempt - 1)
            Write-TBLog -Message ('Webhook notification attempt {0} failed: {1}. Retrying in {2}s.' -f $attempt, $_.Exception.Message, $delaySeconds) -Level 'Warning'
            Start-Sleep -Seconds $delaySeconds
        }
    }
}
