function Compare-TBSnapshot {
    <#
    .SYNOPSIS
        Compares two tenant configuration snapshots.
    .DESCRIPTION
        Downloads the content of two snapshots and compares resource properties
        between them. Returns an array of diff objects indicating what changed,
        was added, or was removed between the reference and difference snapshots.
    .PARAMETER ReferenceSnapshotId
        The ID of the reference (baseline) snapshot.
    .PARAMETER DifferenceSnapshotId
        The ID of the difference (comparison) snapshot.
    .PARAMETER OutputPath
        Optional file path to export the comparison as JSON.
    .EXAMPLE
        Compare-TBSnapshot -ReferenceSnapshotId 'aaa...' -DifferenceSnapshotId 'bbb...'
    .EXAMPLE
        Compare-TBSnapshot -ReferenceSnapshotId 'aaa...' -DifferenceSnapshotId 'bbb...' -OutputPath './diff.json'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReferenceSnapshotId,

        [Parameter(Mandatory = $true)]
        [string]$DifferenceSnapshotId,

        [Parameter()]
        [string]$OutputPath
    )

    # Fetch both snapshots
    $refSnapshot = Get-TBSnapshot -SnapshotId $ReferenceSnapshotId
    $diffSnapshot = Get-TBSnapshot -SnapshotId $DifferenceSnapshotId

    foreach ($snap in @($refSnapshot, $diffSnapshot)) {
        if ($snap.Status -ne 'succeeded' -and $snap.Status -ne 'partiallySuccessful') {
            Write-TBLog -Message ('Snapshot {0} status is {1}. Only succeeded or partiallySuccessful snapshots can be compared.' -f $snap.Id, $snap.Status) -Level 'Warning'
            return
        }
        if (-not $snap.ResourceLocation) {
            Write-TBLog -Message ('Snapshot {0} has no ResourceLocation.' -f $snap.Id) -Level 'Warning'
            return
        }
    }

    Write-TBLog -Message ('Downloading reference snapshot content: {0}' -f $ReferenceSnapshotId)
    $refContent = Invoke-TBGraphRequest -Uri $refSnapshot.ResourceLocation -Method 'GET'

    Write-TBLog -Message ('Downloading difference snapshot content: {0}' -f $DifferenceSnapshotId)
    $diffContent = Invoke-TBGraphRequest -Uri $diffSnapshot.ResourceLocation -Method 'GET'

    # Build lookup tables keyed by resourceType+displayName
    $refLookup = @{}
    $diffLookup = @{}

    foreach ($item in @($refContent)) {
        $key = Get-TBSnapshotResourceKey -Resource $item
        $refLookup[$key] = $item
    }

    foreach ($item in @($diffContent)) {
        $key = Get-TBSnapshotResourceKey -Resource $item
        $diffLookup[$key] = $item
    }

    $diffs = [System.Collections.ArrayList]::new()

    # Find changed and removed
    foreach ($key in $refLookup.Keys) {
        $refItem = $refLookup[$key]
        $refProps = Get-TBCompareResourceProperties -Resource $refItem

        if ($diffLookup.ContainsKey($key)) {
            $diffItem = $diffLookup[$key]
            $diffProps = Get-TBCompareResourceProperties -Resource $diffItem

            # Compare properties
            $allPropNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($p in $refProps.Keys) { $null = $allPropNames.Add($p) }
            foreach ($p in $diffProps.Keys) { $null = $allPropNames.Add($p) }

            foreach ($propName in $allPropNames) {
                $refVal = if ($refProps.ContainsKey($propName)) { $refProps[$propName] } else { $null }
                $diffVal = if ($diffProps.ContainsKey($propName)) { $diffProps[$propName] } else { $null }

                $refStr = ConvertTo-TBCompareString -Value $refVal
                $diffStr = ConvertTo-TBCompareString -Value $diffVal

                if ($refStr -ne $diffStr) {
                    $diffType = if ($null -eq $refVal) { 'Added' }
                                elseif ($null -eq $diffVal) { 'Removed' }
                                else { 'Changed' }

                    $parts = $key -split '\|', 2
                    $null = $diffs.Add([PSCustomObject]@{
                        ResourceType     = $parts[0]
                        ResourceName     = if ($parts.Count -gt 1) { $parts[1] } else { '' }
                        Property         = $propName
                        ReferenceValue   = $refStr
                        DifferenceValue  = $diffStr
                        DiffType         = $diffType
                    })
                }
            }
        }
        else {
            # Resource removed in difference
            $parts = $key -split '\|', 2
            $null = $diffs.Add([PSCustomObject]@{
                ResourceType     = $parts[0]
                ResourceName     = if ($parts.Count -gt 1) { $parts[1] } else { '' }
                Property         = '(entire resource)'
                ReferenceValue   = 'present'
                DifferenceValue  = 'absent'
                DiffType         = 'Removed'
            })
        }
    }

    # Find added resources
    foreach ($key in $diffLookup.Keys) {
        if (-not $refLookup.ContainsKey($key)) {
            $parts = $key -split '\|', 2
            $null = $diffs.Add([PSCustomObject]@{
                ResourceType     = $parts[0]
                ResourceName     = if ($parts.Count -gt 1) { $parts[1] } else { '' }
                Property         = '(entire resource)'
                ReferenceValue   = 'absent'
                DifferenceValue  = 'present'
                DiffType         = 'Added'
            })
        }
    }

    if ($OutputPath) {
        $parentDir = Split-Path -Path $OutputPath -Parent
        if ($parentDir -and -not (Test-Path -Path $parentDir)) {
            $null = New-Item -Path $parentDir -ItemType Directory -Force
        }

        $exportData = [PSCustomObject]@{
            ComparedAt           = (Get-Date).ToString('o')
            ReferenceSnapshotId  = $ReferenceSnapshotId
            DifferenceSnapshotId = $DifferenceSnapshotId
            DiffCount            = $diffs.Count
            Diffs                = @($diffs)
        }
        $exportData | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputPath -Encoding utf8 -Force
        Write-TBLog -Message ('Comparison exported to: {0}' -f $OutputPath)
    }

    return @($diffs)
}
