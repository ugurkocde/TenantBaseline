function ConvertFrom-TBDriftResponse {
    <#
    .SYNOPSIS
        Converts a raw Graph API drift response into a typed PSCustomObject.
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
        PSTypeName                  = 'TenantBaseline.Drift'
        Id                          = $null
        MonitorId                   = $null
        TenantId                    = $null
        ResourceType                = $null
        BaselineResourceDisplayName = $null
        FirstReportedDateTime       = $null
        Status                      = $null
        ResourceInstanceIdentifier  = $null
        DriftedProperties           = @()
        RawResponse                 = $Response
    }

    if ($obj.PSObject.Properties['id']) { $result.Id = $obj.id }
    if ($obj.PSObject.Properties['monitorId']) { $result.MonitorId = $obj.monitorId }
    if ($obj.PSObject.Properties['tenantId']) { $result.TenantId = $obj.tenantId }
    if ($obj.PSObject.Properties['resourceType']) { $result.ResourceType = $obj.resourceType }
    if ($obj.PSObject.Properties['baselineResourceDisplayName']) { $result.BaselineResourceDisplayName = $obj.baselineResourceDisplayName }
    if ($obj.PSObject.Properties['firstReportedDateTime']) { $result.FirstReportedDateTime = $obj.firstReportedDateTime }
    if ($obj.PSObject.Properties['status']) { $result.Status = $obj.status }
    if ($obj.PSObject.Properties['resourceInstanceIdentifier']) { $result.ResourceInstanceIdentifier = $obj.resourceInstanceIdentifier }
    if ($obj.PSObject.Properties['driftedProperties']) { $result.DriftedProperties = $obj.driftedProperties }

    return $result
}
