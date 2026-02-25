function New-TBBaselineSnapshot {
    <#
    .SYNOPSIS
        Creates a snapshot from a monitor's baseline configuration.
    .DESCRIPTION
        Initiates a snapshot job using the resource types defined in a monitor's
        baseline. This captures the current tenant state for all resources the
        monitor tracks, useful for before/after comparisons or archiving.
    .PARAMETER MonitorId
        The ID of the monitor whose baseline resources to snapshot.
    .PARAMETER DisplayName
        Display name for the snapshot. Defaults to '<MonitorDisplayName> Snapshot'.
    .PARAMETER Description
        Optional description of the snapshot.
    .EXAMPLE
        New-TBBaselineSnapshot -MonitorId '00000000-...'
    .EXAMPLE
        Get-TBMonitor | New-TBBaselineSnapshot
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$MonitorId,

        [Parameter()]
        [string]$DisplayName,

        [Parameter()]
        [string]$Description
    )

    process {
        $baseline = Get-TBBaseline -MonitorId $MonitorId

        $resourceTypes = @()
        if ($baseline.Resources) {
            foreach ($r in $baseline.Resources) {
                $rt = $null
                if ($r -is [hashtable]) {
                    $rt = $r['resourceType']
                }
                elseif ($r.PSObject.Properties['resourceType']) {
                    $rt = $r.resourceType
                }
                if ($rt) {
                    $resourceTypes += $rt
                }
            }
        }

        if ($resourceTypes.Count -eq 0) {
            Write-TBLog -Message 'No resource types found in monitor baseline.' -Level 'Warning'
            return
        }

        if (-not $DisplayName) {
            $monitorName = $baseline.DisplayName
            if (-not $monitorName) {
                $monitorName = $MonitorId.Substring(0, 8)
            }
            $DisplayName = '{0} Snapshot' -f $monitorName
            # Sanitize to API-allowed characters and enforce length bounds
            $DisplayName = $DisplayName -replace '[^a-zA-Z0-9 ]', ' '
            if ($DisplayName.Length -gt 32) {
                $DisplayName = $DisplayName.Substring(0, 32)
            }
            if ($DisplayName.Length -lt 8) {
                $DisplayName = $DisplayName.PadRight(8)
            }
        }

        $body = @{
            displayName = $DisplayName
            resources   = @($resourceTypes)
        }

        if ($Description) {
            $body['description'] = $Description
        }

        $uri = '{0}/configurationSnapshots/createSnapshot' -f (Get-TBApiBaseUri)

        if ($PSCmdlet.ShouldProcess($DisplayName, 'Create snapshot from monitor baseline')) {
            Write-TBLog -Message ('Creating baseline snapshot for monitor {0}: {1}' -f $MonitorId, $DisplayName)
            $response = Invoke-TBGraphRequest -Uri $uri -Method 'POST' -Body $body
            return ConvertFrom-TBSnapshotResponse -Response $response
        }
    }
}
