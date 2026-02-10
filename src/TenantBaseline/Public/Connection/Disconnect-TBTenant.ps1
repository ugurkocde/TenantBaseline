function Disconnect-TBTenant {
    <#
    .SYNOPSIS
        Disconnects from Microsoft Graph and clears the module session state.
    .DESCRIPTION
        Wraps Disconnect-MgGraph and resets the module-scoped connection tracking.
    .EXAMPLE
        Disconnect-TBTenant
    #>
    [CmdletBinding()]
    param()

    Write-TBLog -Message 'Disconnecting from Microsoft Graph'

    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
    }
    catch {
        Write-TBLog -Message ('Disconnect-MgGraph returned: {0}' -f $_) -Level 'Warning'
    }

    $script:TBConnection = $null
    Write-TBLog -Message 'Disconnected and session state cleared'
    Write-Output 'Disconnected from Microsoft Graph.'
}
