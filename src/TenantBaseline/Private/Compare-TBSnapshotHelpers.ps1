function Get-TBSnapshotResourceKey {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Resource)

    $rt = $null
    $dn = $null
    if ($Resource -is [hashtable]) {
        $rt = $Resource['resourceType']
        $dn = $Resource['displayName']
    }
    else {
        if ($Resource.PSObject.Properties['resourceType']) { $rt = $Resource.resourceType }
        if ($Resource.PSObject.Properties['displayName']) { $dn = $Resource.displayName }
    }

    return ('{0}|{1}' -f $rt, $dn)
}

function Get-TBCompareResourceProperties {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Resource)

    $props = @{}
    $raw = $null
    if ($Resource -is [hashtable]) {
        $raw = $Resource['properties']
    }
    elseif ($Resource.PSObject.Properties['properties']) {
        $raw = $Resource.properties
    }

    if ($null -eq $raw) { return $props }

    if ($raw -is [hashtable]) {
        foreach ($k in $raw.Keys) { $props[$k] = $raw[$k] }
    }
    elseif ($raw.PSObject.Properties) {
        foreach ($p in $raw.PSObject.Properties) { $props[$p.Name] = $p.Value }
    }

    return $props
}

function ConvertTo-TBCompareString {
    [CmdletBinding()]
    param([Parameter()][object]$Value)

    if ($null -eq $Value) { return '' }
    if ($Value -is [string]) { return $Value }
    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return ($Value | ForEach-Object { "$_" }) -join ', '
    }
    return "$Value"
}
