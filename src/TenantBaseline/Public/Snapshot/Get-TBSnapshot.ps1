function Get-TBSnapshot {
    <#
    .SYNOPSIS
        Gets one or all snapshot jobs.
    .DESCRIPTION
        Retrieves snapshot jobs from the UTCM API. Can get a specific snapshot
        by ID or list all snapshots.
    .PARAMETER SnapshotId
        The ID of a specific snapshot to retrieve.
    .EXAMPLE
        Get-TBSnapshot
        Lists all snapshot jobs.
    .EXAMPLE
        Get-TBSnapshot -SnapshotId '00000000-...'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$SnapshotId
    )

    process {
        $baseUri = Get-TBApiBaseUri

        if ($SnapshotId) {
            $uri = '{0}/configurationSnapshotJobs/{1}' -f $baseUri, $SnapshotId
            Write-TBLog -Message ('Getting snapshot: {0}' -f $SnapshotId)
            $response = Invoke-TBGraphRequest -Uri $uri -Method 'GET'
            return ConvertFrom-TBSnapshotResponse -Response $response
        }
        else {
            $uri = '{0}/configurationSnapshotJobs' -f $baseUri
            Write-TBLog -Message 'Listing all snapshots'
            $items = Invoke-TBGraphPagedRequest -Uri $uri

            foreach ($item in $items) {
                ConvertFrom-TBSnapshotResponse -Response $item
            }
        }
    }
}
