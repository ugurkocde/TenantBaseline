function Remove-TBSnapshot {
    <#
    .SYNOPSIS
        Deletes a snapshot job.
    .DESCRIPTION
        Removes a snapshot job by ID from the UTCM API.
    .PARAMETER SnapshotId
        The ID of the snapshot to delete.
    .EXAMPLE
        Remove-TBSnapshot -SnapshotId '00000000-...'
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [string]$SnapshotId
    )

    process {
        $uri = '{0}/configurationSnapshotJobs/{1}' -f (Get-TBApiBaseUri), $SnapshotId

        if ($PSCmdlet.ShouldProcess($SnapshotId, 'Delete snapshot job')) {
            Write-TBLog -Message ('Deleting snapshot: {0}' -f $SnapshotId)
            $null = Invoke-TBGraphRequest -Uri $uri -Method 'DELETE'
            Write-TBLog -Message ('Snapshot {0} deleted' -f $SnapshotId)
        }
    }
}
