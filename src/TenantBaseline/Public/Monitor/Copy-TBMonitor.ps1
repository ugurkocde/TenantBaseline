function Copy-TBMonitor {
    <#
    .SYNOPSIS
        Clones an existing configuration monitor with a new name.
    .DESCRIPTION
        Reads the source monitor's baseline and creates a new monitor with the
        same resource configuration but a different display name. Useful for
        creating variants of existing monitors.
    .PARAMETER MonitorId
        The ID of the monitor to clone.
    .PARAMETER DisplayName
        The display name for the new monitor.
    .PARAMETER Description
        Optional description for the new monitor.
    .EXAMPLE
        Copy-TBMonitor -MonitorId '00000000-...' -DisplayName 'Cloned Monitor'
    .EXAMPLE
        Get-TBMonitor -MonitorId '00000000-...' | Copy-TBMonitor -DisplayName 'Clone'
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$MonitorId,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter()]
        [string]$Description
    )

    process {
        $sourceMonitor = Get-TBMonitor -MonitorId $MonitorId
        $sourceBaseline = Get-TBBaseline -MonitorId $MonitorId

        $createParams = @{
            DisplayName = $DisplayName
        }

        if ($Description) {
            $createParams['Description'] = $Description
        }
        elseif ($sourceMonitor.Description) {
            $createParams['Description'] = $sourceMonitor.Description
        }

        if ($sourceBaseline.Resources -and @($sourceBaseline.Resources).Count -gt 0) {
            $createParams['Resources'] = @($sourceBaseline.Resources)
        }

        if ($sourceBaseline.Parameters -and @($sourceBaseline.Parameters).Count -gt 0) {
            $createParams['Parameters'] = $sourceBaseline.Parameters
        }

        if ($PSCmdlet.ShouldProcess($DisplayName, ('Clone monitor from {0}' -f $sourceMonitor.DisplayName))) {
            Write-TBLog -Message ('Cloning monitor {0} as {1}' -f $MonitorId, $DisplayName)
            $result = New-TBMonitor @createParams -Confirm:$false
            return $result
        }
    }
}
