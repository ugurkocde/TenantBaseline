function New-TBSnapshot {
    <#
    .SYNOPSIS
        Creates a new tenant configuration snapshot.
    .DESCRIPTION
        Initiates a snapshot job that captures the current tenant configuration
        for the specified resource types. Snapshots expire after 7 days.
    .PARAMETER DisplayName
        Display name for the snapshot.
    .PARAMETER Description
        Optional description of the snapshot.
    .PARAMETER Resources
        Array of resource type names to include (e.g., 'microsoft.exchange.sharedmailbox').
    .EXAMPLE
        New-TBSnapshot -DisplayName 'Weekly Snapshot' -Resources @('microsoft.exchange.sharedmailbox')
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter()]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string[]]$Resources
    )

    $uri = '{0}/configurationSnapshots/createSnapshot' -f (Get-TBApiBaseUri)

    $body = @{
        displayName = $DisplayName
        resources   = @($Resources)
    }

    if ($Description) {
        $body['description'] = $Description
    }

    if ($PSCmdlet.ShouldProcess($DisplayName, 'Create configuration snapshot')) {
        Write-TBLog -Message ('Creating snapshot: {0}' -f $DisplayName)
        $response = Invoke-TBGraphRequest -Uri $uri -Method 'POST' -Body $body
        return ConvertFrom-TBSnapshotResponse -Response $response
    }
}
