function Test-TBGraphConnection {
    <#
    .SYNOPSIS
        Validates that a Microsoft Graph connection is active.
    .DESCRIPTION
        Checks whether Connect-MgGraph has been called and a valid context exists.
        Throws a terminating error if not connected.
    #>
    [CmdletBinding()]
    param()

    try {
        $context = Get-MgContext
    }
    catch {
        $context = $null
    }

    if (-not $context) {
        $errorMessage = 'Not connected to Microsoft Graph. Run Connect-TBTenant first.'
        Write-TBLog -Message $errorMessage -Level 'Error'
        throw $errorMessage
    }

    return $true
}
