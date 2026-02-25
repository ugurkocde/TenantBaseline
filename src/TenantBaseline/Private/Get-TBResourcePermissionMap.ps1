function Get-TBResourcePermissionMap {
    <#
    .SYNOPSIS
        Returns workload permission profiles used by setup commands.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $catalog = Get-TBUTCMCatalog
    $map = @{}

    foreach ($profileEntry in $catalog.PermissionProfiles.PSObject.Properties) {
        $map[$profileEntry.Name] = @($profileEntry.Value.AutoGrantGraphPermissions)
    }

    $union = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($key in $map.Keys) {
        foreach ($perm in $map[$key]) {
            if ($perm) {
                $null = $union.Add($perm)
            }
        }
    }

    $map['MultiWorkload'] = @($union | Sort-Object)
    return $map
}
