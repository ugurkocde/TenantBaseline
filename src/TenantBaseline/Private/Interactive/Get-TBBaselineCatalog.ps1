function Get-TBBaselineCatalog {
    <#
    .SYNOPSIS
        Returns the EIDSCA-based baseline security catalog.
    .DESCRIPTION
        Loads baseline catalog metadata from the tracked JSON artifact and
        caches it for the lifetime of the module session.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [switch]$ForceReload
    )

    if (-not $ForceReload -and $script:TBBaselineCatalog) {
        return $script:TBBaselineCatalog
    }

    $catalogPath = Join-Path -Path $script:TBModuleRoot -ChildPath 'Data/BaselineCatalog.json'
    if (-not (Test-Path -Path $catalogPath -PathType Leaf)) {
        throw "Baseline catalog file not found: $catalogPath"
    }

    $raw = Get-Content -Path $catalogPath -Raw -ErrorAction Stop
    $script:TBBaselineCatalog = $raw | ConvertFrom-Json -Depth 25
    return $script:TBBaselineCatalog
}
