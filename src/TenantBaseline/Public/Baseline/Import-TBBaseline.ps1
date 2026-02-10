function Import-TBBaseline {
    <#
    .SYNOPSIS
        Imports a baseline from a local JSON file.
    .DESCRIPTION
        Reads a previously exported baseline JSON file and returns the resources
        as objects that can be piped to New-TBMonitor.
    .PARAMETER Path
        The path to the baseline JSON file.
    .EXAMPLE
        Import-TBBaseline -Path './baselines/mfa.json' | New-TBMonitor -DisplayName 'MFA Monitor'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string]$Path
    )

    Write-TBLog -Message ('Importing baseline from: {0}' -f $Path)

    $content = Get-Content -Path $Path -Raw
    $data = $content | ConvertFrom-Json

    if ($data.PSObject.Properties['Resources']) {
        foreach ($resource in $data.Resources) {
            $resource
        }
    }
    else {
        Write-TBLog -Message 'No Resources property found in baseline file. Returning raw content.' -Level 'Warning'
        $data
    }
}
