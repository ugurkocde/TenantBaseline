function Test-TBArrowKeySupport {
    <#
    .SYNOPSIS
        Checks if the current host supports arrow-key interactive menus.
    .DESCRIPTION
        Returns $true on PowerShell 7+ with an interactive console host that
        supports RawUI key reading. Returns $false on unsupported hosts such as ISE, CI runners,
        Pester test hosts, and non-interactive sessions.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Require PS 7+
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        return $false
    }

    # Non-interactive session
    if (-not [Environment]::UserInteractive) {
        return $false
    }

    # Check for ConsoleHost (excludes ISE, VS Code output pane, Pester hosts)
    if ($Host.Name -ne 'ConsoleHost') {
        return $false
    }

    # Verify RawUI is available and functional
    try {
        $null = $Host.UI.RawUI.KeyAvailable
        return $true
    }
    catch {
        return $false
    }
}
