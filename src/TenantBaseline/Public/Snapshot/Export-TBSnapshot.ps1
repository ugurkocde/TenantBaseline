function Export-TBSnapshot {
    <#
    .SYNOPSIS
        Exports a snapshot to a local JSON file.
    .DESCRIPTION
        Downloads the snapshot content from the ResourceLocation URL and saves
        it to a local JSON file before the 7-day expiration. The exported file
        contains the actual tenant configuration data captured by the snapshot.
    .PARAMETER SnapshotId
        The ID of the snapshot to export.
    .PARAMETER OutputPath
        The file path to save the snapshot JSON. Defaults to
        'TBSnapshot-{id}-{date}.json' in the current directory.
    .EXAMPLE
        Export-TBSnapshot -SnapshotId '00000000-...'
    .EXAMPLE
        Export-TBSnapshot -SnapshotId '00000000-...' -OutputPath './snapshots/latest.json'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$SnapshotId,

        [Parameter()]
        [string]$OutputPath
    )

    process {
        $snapshot = Get-TBSnapshot -SnapshotId $SnapshotId

        if ($snapshot.Status -ne 'succeeded' -and $snapshot.Status -ne 'partiallySuccessful') {
            Write-TBLog -Message ('Snapshot status is {0}. Only succeeded or partiallySuccessful snapshots can be exported.' -f $snapshot.Status) -Level 'Warning'
            return
        }

        if (-not $snapshot.ResourceLocation) {
            Write-TBLog -Message 'Snapshot has no ResourceLocation. Cannot download content.' -Level 'Warning'
            return
        }

        # Fetch the actual snapshot content from the ResourceLocation
        Write-TBLog -Message ('Downloading snapshot content from: {0}' -f $snapshot.ResourceLocation)
        $content = Invoke-TBGraphRequest -Uri $snapshot.ResourceLocation -Method 'GET'

        if (-not $OutputPath) {
            $dateStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $OutputPath = 'TBSnapshot-{0}-{1}.json' -f $SnapshotId.Substring(0, 8), $dateStamp
        }

        $parentDir = Split-Path -Path $OutputPath -Parent
        if ($parentDir -and -not (Test-Path -Path $parentDir)) {
            $null = New-Item -Path $parentDir -ItemType Directory -Force
        }

        $exportData = [PSCustomObject]@{
            ExportedAt        = (Get-Date).ToString('o')
            SnapshotId        = $snapshot.Id
            DisplayName       = $snapshot.DisplayName
            Status            = $snapshot.Status
            CreatedDateTime   = $snapshot.CreatedDateTime
            CompletedDateTime = $snapshot.CompletedDateTime
            Resources         = $snapshot.Resources
            Content           = $content
        }

        $json = $exportData | ConvertTo-Json -Depth 20
        $json | Out-File -FilePath $OutputPath -Encoding utf8 -Force

        Write-TBLog -Message ('Snapshot exported to: {0}' -f $OutputPath)

        [PSCustomObject]@{
            SnapshotId = $SnapshotId
            OutputPath = (Resolve-Path -Path $OutputPath).Path
            ExportedAt = $exportData.ExportedAt
        }
    }
}
