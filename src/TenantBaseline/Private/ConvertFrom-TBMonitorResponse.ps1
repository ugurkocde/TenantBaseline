function ConvertFrom-TBMonitorResponse {
    <#
    .SYNOPSIS
        Converts a raw Graph API monitor response into a typed PSCustomObject.
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
        PSTypeName              = 'TenantBaseline.Monitor'
        Id                      = $null
        DisplayName             = $null
        Description             = $null
        Status                  = $null
        Mode                    = $null
        MonitorRunFrequencyInHours = $null
        InactivationReason      = $null
        TenantId                = $null
        CreatedBy               = $null
        CreatedDateTime         = $null
        LastModifiedBy          = $null
        LastModifiedDateTime    = $null
        Parameters              = $null
        RawResponse             = $Response
    }

    if ($obj.PSObject.Properties['id']) { $result.Id = $obj.id }
    if ($obj.PSObject.Properties['displayName']) { $result.DisplayName = $obj.displayName }
    if ($obj.PSObject.Properties['description']) { $result.Description = $obj.description }
    if ($obj.PSObject.Properties['status']) { $result.Status = $obj.status }
    if ($obj.PSObject.Properties['mode']) { $result.Mode = $obj.mode }
    if ($obj.PSObject.Properties['monitorRunFrequencyInHours']) { $result.MonitorRunFrequencyInHours = $obj.monitorRunFrequencyInHours }
    if ($obj.PSObject.Properties['inactivationReason']) { $result.InactivationReason = $obj.inactivationReason }
    if ($obj.PSObject.Properties['tenantId']) { $result.TenantId = $obj.tenantId }
    if ($obj.PSObject.Properties['createdBy']) { $result.CreatedBy = $obj.createdBy }
    if ($obj.PSObject.Properties['createdDateTime']) { $result.CreatedDateTime = $obj.createdDateTime }
    if ($obj.PSObject.Properties['lastModifiedBy']) { $result.LastModifiedBy = $obj.lastModifiedBy }
    if ($obj.PSObject.Properties['lastModifiedDateTime']) { $result.LastModifiedDateTime = $obj.lastModifiedDateTime }
    if ($obj.PSObject.Properties['parameters']) { $result.Parameters = $obj.parameters }

    return $result
}
