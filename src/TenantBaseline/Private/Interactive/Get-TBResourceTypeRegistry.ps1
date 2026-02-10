function Get-TBResourceTypeRegistry {
    <#
    .SYNOPSIS
        Returns supported UTCM resource types grouped by workload.
    .DESCRIPTION
        Builds the registry from the tracked UTCM catalog so interactive menus
        and validation all use the same canonical source.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $catalog = Get-TBUTCMCatalog

    $registry = @{}
    foreach ($resource in $catalog.Resources) {
        $workloadName = $resource.WorkloadDisplayName
        if (-not $registry.ContainsKey($workloadName)) {
            $registry[$workloadName] = @{
                WorkloadId    = $resource.WorkloadId
                ResourceTypes = @()
            }
        }

        $displayName = if ($resource.DisplayName) {
            $resource.DisplayName
        }
        else {
            $resource.ShortName
        }

        $registry[$workloadName].ResourceTypes += @{
            Name        = $resource.Name
            DisplayName = $displayName
            ShortName   = $resource.ShortName
            Provider    = $resource.Provider
        }
    }

    foreach ($workload in $registry.Keys) {
        $registry[$workload].ResourceTypes = @($registry[$workload].ResourceTypes | Sort-Object -Property Name)
    }

    return $registry
}
