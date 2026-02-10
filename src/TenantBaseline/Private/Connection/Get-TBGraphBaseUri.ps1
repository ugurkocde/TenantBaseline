function Get-TBGraphBaseUri {
    <#
    .SYNOPSIS
        Returns the Microsoft Graph base URL for the current session environment.
    .DESCRIPTION
        Reads the environment from the active Get-MgContext session and maps it
        to the correct Graph API host. Defaults to the Global cloud when no
        context is available.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $context = Get-MgContext
    $envName = if ($context -and $context.Environment) { $context.Environment } else { 'Global' }

    switch ($envName) {
        'USGov'    { return 'https://graph.microsoft.us' }
        'USGovDoD' { return 'https://dod-graph.microsoft.us' }
        'China'    { return 'https://microsoftgraph.chinacloudapi.cn' }
        default    { return 'https://graph.microsoft.com' }
    }
}
