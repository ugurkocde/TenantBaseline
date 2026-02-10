function ConvertTo-TBMonitorBody {
    <#
    .SYNOPSIS
        Converts monitor parameters into a Graph API request body hashtable.
    .DESCRIPTION
        Builds the nested structure expected by the UTCM API, with a baseline
        object containing resources nested inside the monitor body.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter()]
        [string]$Description,

        [Parameter()]
        [string]$BaselineDisplayName,

        [Parameter()]
        [string]$BaselineDescription,

        [Parameter()]
        [object[]]$Resources,

        [Parameter()]
        [hashtable]$Parameters
    )

    $body = @{
        displayName = $DisplayName
    }

    if ($Description) {
        $body['description'] = $Description
    }

    if ($Parameters) {
        $body['parameters'] = $Parameters
    }

    # Build the nested baseline object
    if ($Resources) {
        $baseline = @{
            resources = @($Resources)
        }

        if ($BaselineDisplayName) {
            $baseline['displayName'] = $BaselineDisplayName
        }
        else {
            $autoName = '{0} Baseline' -f $DisplayName
            if ($autoName.Length -gt 32) {
                $autoName = $DisplayName.Substring(0, [math]::Min($DisplayName.Length, 23)) + ' Baseline'
            }
            $baseline['displayName'] = $autoName
        }

        if ($BaselineDescription) {
            $baseline['description'] = $BaselineDescription
        }

        $body['baseline'] = $baseline
    }

    return $body
}
