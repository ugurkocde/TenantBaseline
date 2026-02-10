function Set-TBMonitor {
    <#
    .SYNOPSIS
        Updates an existing configuration monitor.
    .DESCRIPTION
        Updates the properties of an existing UTCM configuration monitor,
        including its display name, description, status, and baseline.
        The API returns 204 No Content on success.
    .PARAMETER MonitorId
        The ID of the monitor to update.
    .PARAMETER DisplayName
        New display name for the monitor.
    .PARAMETER Description
        New description for the monitor.
    .PARAMETER Status
        New status for the monitor. Valid values: active, inactive.
    .PARAMETER Resources
        Updated array of baseline resource objects.
    .PARAMETER BaselineDisplayName
        Display name for the updated baseline.
    .PARAMETER BaselineDescription
        Description for the updated baseline.
    .PARAMETER Parameters
        Updated key-value pairs for baseline parameter values.
    .EXAMPLE
        Set-TBMonitor -MonitorId '00000000-...' -DisplayName 'Updated Monitor'
    .EXAMPLE
        Set-TBMonitor -MonitorId '00000000-...' -Status 'inactive'
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$MonitorId,

        [Parameter()]
        [string]$DisplayName,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [ValidateSet('active', 'inactive')]
        [string]$Status,

        [Parameter()]
        [object[]]$Resources,

        [Parameter()]
        [string]$BaselineDisplayName,

        [Parameter()]
        [string]$BaselineDescription,

        [Parameter()]
        [hashtable]$Parameters
    )

    process {
        $body = @{}

        if ($DisplayName) { $body['displayName'] = $DisplayName }
        if ($Description) { $body['description'] = $Description }
        if ($Status) { $body['status'] = $Status }
        if ($Parameters) { $body['parameters'] = $Parameters }

        if ($Resources) {
            $warningTracker = @{}
            $converted = foreach ($r in $Resources) {
                ConvertTo-TBBaselineResource -Resource $r -WarningTracker $warningTracker
            }
            $baseline = @{
                resources = @($converted)
            }
            if ($BaselineDisplayName) {
                $baseline['displayName'] = $BaselineDisplayName
            }
            if ($BaselineDescription) {
                $baseline['description'] = $BaselineDescription
            }
            $body['baseline'] = $baseline
        }

        if ($body.Count -eq 0) {
            Write-TBLog -Message 'No properties specified to update.' -Level 'Warning'
            return
        }

        $uri = '{0}/configurationMonitors/{1}' -f (Get-TBApiBaseUri), $MonitorId

        if ($PSCmdlet.ShouldProcess($MonitorId, 'Update configuration monitor')) {
            Write-TBLog -Message ('Updating monitor: {0}' -f $MonitorId)
            $null = Invoke-TBGraphRequest -Uri $uri -Method 'PATCH' -Body $body
            Write-TBLog -Message ('Monitor {0} updated' -f $MonitorId)
        }
    }
}
