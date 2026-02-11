function ConvertTo-TBBaselineResource {
    <#
    .SYNOPSIS
        Converts a baseline resource definition into the API-expected format.
    .DESCRIPTION
        Takes a resource definition (with resourceType, properties, etc.)
        and converts it into the format expected by the UTCM monitor API.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Resource,

        [Parameter()]
        [hashtable]$WarningTracker
    )

    if ($Resource -is [hashtable]) {
        $obj = [PSCustomObject]$Resource
    }
    else {
        $obj = $Resource
    }

    $result = @{}

    if ($obj.PSObject.Properties['resourceType']) {
        if (-not $WarningTracker) {
            $WarningTracker = @{}
        }

        $resolved = Resolve-TBResourceType -ResourceType $obj.resourceType -WarningTracker $WarningTracker
        $result['resourceType'] = $resolved.CanonicalResourceType
    }

    if ($obj.PSObject.Properties['properties']) {
        $result['properties'] = $obj.properties

        # Warn when properties is empty -- the API will reject this if the
        # resource type has no existing policy in the tenant.
        $propsEmpty = $false
        if ($obj.properties -is [hashtable]) {
            $propsEmpty = $obj.properties.Count -eq 0
        }
        elseif ($obj.properties.PSObject.Properties) {
            $propsEmpty = @($obj.properties.PSObject.Properties).Count -eq 0
        }
        if ($propsEmpty) {
            Write-TBLog -Message ('Resource "{0}" has empty properties. The API may reject this if the resource type has no existing tenant configuration.' -f ($obj.resourceType)) -Level 'Warning'
        }
    }

    if ($obj.PSObject.Properties['displayName']) {
        $result['displayName'] = $obj.displayName
    }

    return $result
}
