function Resolve-TBResourceType {
    <#
    .SYNOPSIS
        Resolves a resource type to its canonical UTCM name.
    .DESCRIPTION
        Supports legacy aliases and stale identifiers. By default aliases are
        auto-migrated and logged as warnings. Unknown resource types throw.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceType,

        [Parameter()]
        [switch]$StrictCanonical,

        [Parameter()]
        [hashtable]$WarningTracker
    )

    $catalog = Get-TBUTCMCatalog
    $canonicalSet = @{}
    foreach ($resource in $catalog.Resources) {
        $canonicalSet[$resource.Name.ToLowerInvariant()] = $true
    }

    $inputType = $ResourceType.Trim()
    if (-not $inputType) {
        throw 'ResourceType cannot be empty.'
    }

    $normalized = $inputType.ToLowerInvariant()
    if ($canonicalSet.ContainsKey($normalized)) {
        return [PSCustomObject]@{
            InputResourceType     = $inputType
            CanonicalResourceType = $normalized
            WasAliased            = $false
        }
    }

    $aliasMap = @{}
    foreach ($entry in $catalog.AliasMap.PSObject.Properties) {
        $aliasMap[$entry.Name.ToLowerInvariant()] = $entry.Value.ToLowerInvariant()
    }

    if ($aliasMap.ContainsKey($normalized)) {
        if ($StrictCanonical) {
            throw ("Resource type '{0}' is legacy. Use canonical name '{1}'." -f $inputType, $aliasMap[$normalized])
        }

        if ($WarningTracker -and -not $WarningTracker.ContainsKey($normalized)) {
            $WarningTracker[$normalized] = $true
            Write-TBLog -Level 'Warning' -Message ("Resource type alias '{0}' is deprecated. Auto-migrating to '{1}'." -f $inputType, $aliasMap[$normalized])
        }

        return [PSCustomObject]@{
            InputResourceType     = $inputType
            CanonicalResourceType = $aliasMap[$normalized]
            WasAliased            = $true
        }
    }

    throw ("Unsupported UTCM resource type '{0}'. Use Get-TBResourceTypeRegistry to list canonical resource types." -f $inputType)
}
