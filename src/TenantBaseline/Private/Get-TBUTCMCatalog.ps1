function Get-TBUTCMCatalog {
    <#
    .SYNOPSIS
        Returns the canonical UTCM resource catalog.
    .DESCRIPTION
        Loads UTCM resource metadata from the tracked catalog JSON artifact and
        caches it for the lifetime of the module session.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$ForceReload
    )

    if (-not $ForceReload -and $script:TBUTCMCatalog) {
        return $script:TBUTCMCatalog
    }

    $catalogPath = Join-Path -Path $script:TBModuleRoot -ChildPath 'Data/UTCMResourceCatalog.json'
    if (-not (Test-Path -Path $catalogPath -PathType Leaf)) {
        throw "UTCM catalog file not found: $catalogPath"
    }

    $raw = Get-Content -Path $catalogPath -Raw -ErrorAction Stop
    $script:TBUTCMCatalog = $raw | ConvertFrom-Json -Depth 25
    return $script:TBUTCMCatalog
}
