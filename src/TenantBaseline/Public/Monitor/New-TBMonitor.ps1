function New-TBMonitor {
    <#
    .SYNOPSIS
        Creates a new configuration monitor.
    .DESCRIPTION
        Creates a new UTCM configuration monitor that tracks specified resources
        for drift against a baseline. Accepts resources directly or from pipeline.
    .PARAMETER DisplayName
        The display name for the monitor.
    .PARAMETER Description
        Optional description of the monitor.
    .PARAMETER BaselineDisplayName
        Optional display name for the baseline. Defaults to '<DisplayName> Baseline'.
    .PARAMETER BaselineDescription
        Optional description for the baseline.
    .PARAMETER Resources
        Array of baseline resource objects to monitor.
    .PARAMETER Parameters
        Optional hashtable of key-value pairs for baseline parameter values.
    .EXAMPLE
        New-TBMonitor -DisplayName 'MFA Monitor' -Resources $resources
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [string]$BaselineDisplayName,

        [Parameter()]
        [string]$BaselineDescription,

        [Parameter(ValueFromPipeline = $true)]
        [object[]]$Resources,

        [Parameter()]
        [hashtable]$Parameters
    )

    begin {
        $allResources = [System.Collections.ArrayList]::new()
    }

    process {
        if ($Resources) {
            foreach ($resource in $Resources) {
                $null = $allResources.Add($resource)
            }
        }
    }

    end {
        $bodyParams = @{
            DisplayName = $DisplayName
        }

        if ($Description) {
            $bodyParams['Description'] = $Description
        }

        if ($BaselineDisplayName) {
            $bodyParams['BaselineDisplayName'] = $BaselineDisplayName
        }

        if ($BaselineDescription) {
            $bodyParams['BaselineDescription'] = $BaselineDescription
        }

        if ($Parameters) {
            $bodyParams['Parameters'] = $Parameters
        }

        if ($allResources.Count -gt 0) {
            $warningTracker = @{}
            $converted = foreach ($r in $allResources) {
                ConvertTo-TBBaselineResource -Resource $r -WarningTracker $warningTracker
            }
            $bodyParams['Resources'] = $converted
        }

        $body = ConvertTo-TBMonitorBody @bodyParams

        $uri = '{0}/configurationMonitors' -f (Get-TBApiBaseUri)

        if ($PSCmdlet.ShouldProcess($DisplayName, 'Create configuration monitor')) {
            Write-TBLog -Message ('Creating monitor: {0}' -f $DisplayName)
            $response = Invoke-TBGraphRequest -Uri $uri -Method 'POST' -Body $body
            return ConvertFrom-TBMonitorResponse -Response $response
        }
    }
}
