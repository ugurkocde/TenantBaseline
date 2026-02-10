function Get-TBResourceCatalogEntry {
    <#
    .SYNOPSIS
        Gets canonical catalog entries for resource types.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ResourceType
    )

    $catalog = Get-TBUTCMCatalog
    $lookup = @{}
    foreach ($resource in $catalog.Resources) {
        $lookup[$resource.Name.ToLowerInvariant()] = $resource
    }

    $entries = @()
    foreach ($type in $ResourceType) {
        $resolved = Resolve-TBResourceType -ResourceType $type
        if ($lookup.ContainsKey($resolved.CanonicalResourceType)) {
            $entries += $lookup[$resolved.CanonicalResourceType]
        }
    }

    return $entries
}
