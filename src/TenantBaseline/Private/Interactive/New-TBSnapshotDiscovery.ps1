function New-TBSnapshotDiscovery {
    <#
    .SYNOPSIS
        Creates a temporary snapshot and extracts resource properties.
    .DESCRIPTION
        Shared helper for monitor creation workflows. Creates an auto-named snapshot
        with retry logic to handle resource types unsupported by the snapshot API,
        waits for completion, parses properties, and returns a result object.
    .PARAMETER ResourceTypes
        Array of resource type strings to include in the snapshot.
    .OUTPUTS
        [PSCustomObject] with properties:
            SnapshotId       - ID of the created snapshot (null if none created)
            Properties       - Hashtable mapping lowercase resource type to properties
            UnsupportedTypes - Array of types the snapshot API rejected
            Success          - Boolean indicating whether usable properties were obtained
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ResourceTypes
    )

    $result = [PSCustomObject]@{
        SnapshotId       = $null
        Properties       = @{}
        UnsupportedTypes = @()
        Success          = $false
    }

    $snapName = 'TB AutoSnap {0}' -f (Get-Date -Format 'yyyyMMdd HHmmss')
    $snapTypes = @($ResourceTypes)
    $unsupportedBySnapshot = @()
    $snap = $null

    # Retry snapshot creation, filtering out types the snapshot API rejects
    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        if ($snapTypes.Count -eq 0) { break }
        try {
            $snap = New-TBSnapshot -DisplayName $snapName -Resources $snapTypes -Confirm:$false
            break
        }
        catch {
            $newUnsupported = @()
            $errBody = $null
            $jsonText = $null

            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $edm = $_.ErrorDetails.Message
                if ($edm -match '(\r?\n){2}') {
                    $parts = $edm -split '(?:\r?\n){2}', 2
                    if ($parts.Count -eq 2 -and $parts[1].Trim()) {
                        $jsonText = $parts[1].Trim()
                    }
                }
                if (-not $jsonText) { $jsonText = $edm }
            }
            if (-not $jsonText) {
                $jsonText = $_.Exception.Message
            }

            if ($jsonText) {
                try { $errBody = $jsonText | ConvertFrom-Json } catch {}
            }

            if ($errBody.error.details) {
                foreach ($detail in $errBody.error.details) {
                    if ($detail.message -match "ResourceType '([^']+)' is not supported") {
                        $newUnsupported += $Matches[1]
                    }
                }
            }
            if ($newUnsupported.Count -gt 0) {
                $unsupportedBySnapshot += $newUnsupported
                $snapTypes = @($snapTypes | Where-Object { $_.ToLower() -notin @($newUnsupported | ForEach-Object { $_.ToLower() }) })
                continue
            }
            # Not an unsupported-type error -- rethrow
            throw
        }
    }

    $result.UnsupportedTypes = $unsupportedBySnapshot

    if ($snap) {
        $result.SnapshotId = $snap.Id
        $snap = Wait-TBSnapshotInteractive -SnapshotId $snap.Id -ResourceCount $snapTypes.Count

        if ($snap.Status -eq 'succeeded' -or $snap.Status -eq 'partiallySuccessful') {
            $result.Properties = Get-TBSnapshotResourceProperties -Snapshot $snap
            $result.Success = $true
        }
    }
    elseif ($unsupportedBySnapshot.Count -eq $ResourceTypes.Count) {
        # All types were unsupported by snapshot -- still a valid (empty) result
        $result.Success = $true
    }

    return $result
}
