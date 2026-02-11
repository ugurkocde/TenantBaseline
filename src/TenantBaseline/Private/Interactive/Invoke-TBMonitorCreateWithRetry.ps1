function Invoke-TBMonitorCreateWithRetry {
    <#
    .SYNOPSIS
        Creates a monitor with retry logic for rejected resource types.
    .DESCRIPTION
        Wraps New-TBMonitor with a retry loop that parses the API error response
        to identify resource types the monitor API does not support (e.g. types
        unsupported in monitorOnly run mode, or types with empty properties).
        Rejected types are removed from the resources list and the call is retried.
    .PARAMETER DisplayName
        Monitor display name.
    .PARAMETER Description
        Optional monitor description.
    .PARAMETER Resources
        Array of resource objects (resourceType, displayName, properties).
    .OUTPUTS
        [PSCustomObject] with properties:
            Result        - The created monitor object (null on failure)
            RejectedTypes - Array of resource type names the monitor API rejected
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter()]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [object[]]$Resources
    )

    $output = [PSCustomObject]@{
        Result        = $null
        RejectedTypes = @()
    }

    $currentResources = @($Resources)

    for ($attempt = 0; $attempt -lt 3; $attempt++) {
        if ($currentResources.Count -eq 0) { break }

        $params = @{
            DisplayName = $DisplayName
            Resources   = $currentResources
            Confirm     = $false
        }
        if ($Description) {
            $params['Description'] = $Description
        }

        try {
            $output.Result = New-TBMonitor @params
            return $output
        }
        catch {
            # Parse rejected resource types from error details
            $rejectedInAttempt = @()
            $errBody = $null
            $jsonText = $null

            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $edm = $_.ErrorDetails.Message
                if ($edm -match '(\r?\n){2}') {
                    $parts = $edm -split '(?:\r?\n){2}', 2
                    if ($parts.Count -eq 2 -and $parts[1].Trim()) {
                        $jsonText = $parts[1].Trim()
                    }
                }
                if (-not $jsonText) { $jsonText = $edm }
            }
            if (-not $jsonText) {
                $jsonText = $_.Exception.Message
            }

            if ($jsonText) {
                try { $errBody = $jsonText | ConvertFrom-Json } catch {}
            }

            if ($errBody.error.details) {
                foreach ($detail in $errBody.error.details) {
                    if ($detail.target -and (
                        $detail.message -match 'is not supported' -or
                        $detail.message -match 'properties cannot be empty'
                    )) {
                        if ($detail.target -notin $rejectedInAttempt) {
                            $rejectedInAttempt += $detail.target
                        }
                    }
                }
            }

            if ($rejectedInAttempt.Count -gt 0) {
                $output.RejectedTypes += $rejectedInAttempt
                $rejectedLower = @($rejectedInAttempt | ForEach-Object { $_.ToLower() })
                $currentResources = @($currentResources | Where-Object {
                    $_.resourceType.ToLower() -notin $rejectedLower
                })
                continue
            }

            # Not a resource-type rejection error -- rethrow
            throw
        }
    }

    # All resources were rejected
    return $output
}
