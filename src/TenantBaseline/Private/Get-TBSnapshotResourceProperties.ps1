function Get-TBSnapshotResourceProperties {
    <#
    .SYNOPSIS
        Downloads snapshot content and extracts resource type properties.
    .DESCRIPTION
        Fetches the snapshot content from its ResourceLocation URL and returns
        a hashtable mapping lowercase resource type names to their properties
        objects. Handles multiple API response shapes defensively:
        flat array, value-wrapped, and resources-wrapped.
    .PARAMETER Snapshot
        A snapshot object (must have Status and ResourceLocation).
    .OUTPUTS
        [hashtable] Keys are lowercase resource type names, values are property objects.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Snapshot
    )

    $result = @{}

    if ($Snapshot.Status -ne 'succeeded' -and $Snapshot.Status -ne 'partiallySuccessful') {
        throw ('Snapshot status is "{0}". Only succeeded or partiallySuccessful snapshots can provide resource properties.' -f $Snapshot.Status)
    }

    if (-not $Snapshot.ResourceLocation) {
        throw 'Snapshot has no ResourceLocation URL. Cannot download content.'
    }

    Write-TBLog -Message ('Downloading snapshot content from: {0}' -f $Snapshot.ResourceLocation)
    $content = Invoke-TBGraphRequest -Uri $Snapshot.ResourceLocation -Method 'GET'

    if (-not $content) {
        Write-TBLog -Message 'Snapshot content is empty.' -Level 'Warning'
        return $result
    }

    # Normalize response to an array of resource items.
    # The API may return:
    #   1. A flat array of resource objects
    #   2. An object with a "value" array
    #   3. An object with a "resources" array
    #   4. A single resource object (array unwrapped by PowerShell)
    $items = $null

    if ($content -is [System.Collections.IEnumerable] -and $content -isnot [hashtable] -and $content -isnot [string]) {
        $items = @($content)
    }
    elseif ($content -is [hashtable]) {
        if ($content.ContainsKey('value')) {
            $items = @($content['value'])
        }
        elseif ($content.ContainsKey('resources')) {
            $items = @($content['resources'])
        }
        elseif ($content.ContainsKey('resourceType')) {
            # Single resource object (array unwrapped)
            $items = @($content)
        }
    }
    else {
        if ($content.PSObject.Properties['value']) {
            $items = @($content.value)
        }
        elseif ($content.PSObject.Properties['resources']) {
            $items = @($content.resources)
        }
        elseif ($content.PSObject.Properties['resourceType']) {
            # Single resource object (array unwrapped)
            $items = @($content)
        }
    }

    if (-not $items) {
        Write-TBLog -Message 'Snapshot content contains no recognizable resource items.' -Level 'Warning'
        return $result
    }

    foreach ($item in $items) {
        $rtName = $null
        $props = $null

        if ($item -is [hashtable]) {
            if ($item.ContainsKey('resourceType')) { $rtName = $item['resourceType'] }
            if ($item.ContainsKey('properties'))   { $props = $item['properties'] }
        }
        else {
            if ($item.PSObject.Properties['resourceType']) { $rtName = $item.resourceType }
            if ($item.PSObject.Properties['properties'])   { $props = $item.properties }
        }

        if (-not $rtName) {
            Write-TBLog -Message 'Skipping snapshot item with no resourceType field.' -Level 'Warning'
            continue
        }

        if (-not $props) {
            Write-TBLog -Message ('Skipping snapshot item "{0}" with no properties field.' -f $rtName) -Level 'Warning'
            continue
        }

        # Check if properties is effectively empty
        $isEmpty = $false
        if ($props -is [hashtable]) {
            $isEmpty = $props.Count -eq 0
        }
        elseif ($props.PSObject.Properties) {
            $isEmpty = @($props.PSObject.Properties).Count -eq 0
        }

        if ($isEmpty) {
            Write-TBLog -Message ('Snapshot item "{0}" has empty properties -- skipping.' -f $rtName) -Level 'Warning'
            continue
        }

        $key = $rtName.ToLower()
        if (-not $result.ContainsKey($key)) {
            $result[$key] = $props
        }
    }

    Write-TBLog -Message ('Extracted properties for {0} resource type(s) from snapshot.' -f $result.Count)
    return $result
}
