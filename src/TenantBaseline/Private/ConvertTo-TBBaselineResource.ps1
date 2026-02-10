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
    }

    if ($obj.PSObject.Properties['displayName']) {
        $result['displayName'] = $obj.displayName
    }

    return $result
}
