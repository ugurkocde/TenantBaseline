function Export-TBMonitor {
    <#
    .SYNOPSIS
        Exports a monitor configuration to a JSON file.
    .DESCRIPTION
        Fetches a monitor and its baseline, then saves the full configuration
        to a JSON file. The exported file can be used to recreate the monitor
        in another tenant or as a backup.
    .PARAMETER MonitorId
        The ID of the monitor to export.
    .PARAMETER OutputPath
        File path for the exported JSON. Defaults to
        'TBMonitor-{displayName}-{date}.json' in the current directory.
    .EXAMPLE
        Export-TBMonitor -MonitorId '00000000-...'
    .EXAMPLE
        Get-TBMonitor | Export-TBMonitor -OutputPath ./exports/
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$MonitorId,

        [Parameter()]
        [string]$OutputPath
    )

    process {
        $monitor = Get-TBMonitor -MonitorId $MonitorId

        $baseline = $null
        try {
            $baseline = Get-TBBaseline -MonitorId $MonitorId
        }
        catch {
            Write-TBLog -Message ('Could not load baseline: {0}' -f $_.Exception.Message) -Level 'Warning'
        }

        if (-not $OutputPath) {
            $safeName = ($monitor.DisplayName -replace '[^a-zA-Z0-9]', '_')
            $dateStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $OutputPath = 'TBMonitor-{0}-{1}.json' -f $safeName, $dateStamp
        }

        # If OutputPath is a directory, generate a filename inside it
        if (Test-Path -Path $OutputPath -PathType Container) {
            $safeName = ($monitor.DisplayName -replace '[^a-zA-Z0-9]', '_')
            $dateStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $OutputPath = Join-Path $OutputPath ('TBMonitor-{0}-{1}.json' -f $safeName, $dateStamp)
        }

        if ($PSCmdlet.ShouldProcess($OutputPath, 'Export monitor configuration')) {
            $parentDir = Split-Path -Path $OutputPath -Parent
            if ($parentDir -and -not (Test-Path -Path $parentDir)) {
                $null = New-Item -Path $parentDir -ItemType Directory -Force
            }

            $exportData = [PSCustomObject]@{
                ExportedAt  = (Get-Date).ToString('o')
                MonitorId   = $monitor.Id
                DisplayName = $monitor.DisplayName
                Description = $monitor.Description
                Status      = $monitor.Status
                Baseline    = if ($baseline) {
                    [PSCustomObject]@{
                        DisplayName = $baseline.DisplayName
                        Description = $baseline.Description
                        Parameters  = $baseline.Parameters
                        Resources   = $baseline.Resources
                    }
                }
                else { $null }
            }

            $json = $exportData | ConvertTo-Json -Depth 20
            $json | Out-File -FilePath $OutputPath -Encoding utf8 -Force

            Write-TBLog -Message ('Monitor exported to: {0}' -f $OutputPath)

            [PSCustomObject]@{
                MonitorId  = $MonitorId
                OutputPath = (Resolve-Path -Path $OutputPath).Path
                ExportedAt = $exportData.ExportedAt
            }
        }
    }
}
