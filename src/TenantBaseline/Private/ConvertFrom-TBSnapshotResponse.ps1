function ConvertFrom-TBSnapshotResponse {
    <#
    .SYNOPSIS
        Converts a raw Graph API snapshot job response into a typed PSCustomObject.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Response
    )

    if ($Response -is [hashtable]) {
        $obj = [PSCustomObject]$Response
    }
    else {
        $obj = $Response
    }

    $result = [PSCustomObject]@{
        PSTypeName        = 'TenantBaseline.Snapshot'
        Id                = $null
        DisplayName       = $null
        Description       = $null
        Status            = $null
        TenantId          = $null
        CreatedDateTime   = $null
        CompletedDateTime = $null
        CreatedBy         = $null
        Resources         = @()
        ResourceLocation  = $null
        ErrorDetails      = @()
        RawResponse       = $Response
    }

    if ($obj.PSObject.Properties['id']) { $result.Id = $obj.id }
    if ($obj.PSObject.Properties['displayName']) { $result.DisplayName = $obj.displayName }
    if ($obj.PSObject.Properties['description']) { $result.Description = $obj.description }
    if ($obj.PSObject.Properties['status']) { $result.Status = $obj.status }
    if ($obj.PSObject.Properties['tenantId']) { $result.TenantId = $obj.tenantId }
    if ($obj.PSObject.Properties['createdDateTime']) { $result.CreatedDateTime = $obj.createdDateTime }
    if ($obj.PSObject.Properties['completedDateTime']) { $result.CompletedDateTime = $obj.completedDateTime }
    if ($obj.PSObject.Properties['createdBy']) { $result.CreatedBy = $obj.createdBy }
    if ($obj.PSObject.Properties['resources']) { $result.Resources = $obj.resources }
    if ($obj.PSObject.Properties['resourceLocation']) { $result.ResourceLocation = $obj.resourceLocation }
    if ($obj.PSObject.Properties['errorDetails']) { $result.ErrorDetails = $obj.errorDetails }

    return $result
}
