function Export-TBBaseline {
    <#
    .SYNOPSIS
        Exports a monitor's baseline to a local JSON file.
    .DESCRIPTION
        Downloads the baseline configuration from a monitor and saves it
        as a JSON file that can be imported later or used for comparison.
    .PARAMETER MonitorId
        The ID of the monitor to export the baseline from.
    .PARAMETER OutputPath
        The file path to save the baseline JSON.
    .EXAMPLE
        Export-TBBaseline -MonitorId '00000000-...' -OutputPath './baselines/mfa.json'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$MonitorId,

        [Parameter()]
        [string]$OutputPath
    )

    process {
        $baseline = Get-TBBaseline -MonitorId $MonitorId

        if (-not $OutputPath) {
            $dateStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $OutputPath = 'TBBaseline-{0}-{1}.json' -f $MonitorId.Substring(0, 8), $dateStamp
        }

        $parentDir = Split-Path -Path $OutputPath -Parent
        if ($parentDir -and -not (Test-Path -Path $parentDir)) {
            $null = New-Item -Path $parentDir -ItemType Directory -Force
        }

        $exportData = [PSCustomObject]@{
            ExportedAt = (Get-Date).ToString('o')
            MonitorId  = $MonitorId
            Resources  = $baseline.Resources
        }

        $json = $exportData | ConvertTo-Json -Depth 20
        $json | Out-File -FilePath $OutputPath -Encoding utf8 -Force

        Write-TBLog -Message ('Baseline exported to: {0}' -f $OutputPath)

        [PSCustomObject]@{
            MonitorId  = $MonitorId
            OutputPath = (Resolve-Path -Path $OutputPath).Path
            ExportedAt = $exportData.ExportedAt
        }
    }
}
