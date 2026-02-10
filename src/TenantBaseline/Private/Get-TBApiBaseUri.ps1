function Get-TBApiBaseUri {
    <#
    .SYNOPSIS
        Returns the UTCM API base URI.
    .DESCRIPTION
        Returns the module-scoped base URI for the UTCM beta API endpoints.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return $script:TBApiBaseUri
}
