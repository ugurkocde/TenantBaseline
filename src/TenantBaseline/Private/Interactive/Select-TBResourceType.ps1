function Select-TBResourceType {
    <#
    .SYNOPSIS
        Interactive workload and resource type picker.
    .DESCRIPTION
        Guides the user through selecting workloads and resource types using
        a two-step menu. Returns an array of selected resource type name strings.
    .PARAMETER SingleWorkload
        If specified, only allows selecting from a single workload.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$SingleWorkload
    )

    $registry = Get-TBResourceTypeRegistry

    # Build workload options with counts
    $workloadNames = @($registry.Keys | Sort-Object)
    $workloadOptions = @()
    foreach ($name in $workloadNames) {
        $count = $registry[$name].ResourceTypes.Count
        $workloadOptions += ('{0} ({1} resource types)' -f $name, $count)
    }

    # Step 1: Pick workload(s)
    if ($SingleWorkload) {
        $workloadResult = Show-TBMenu -Title 'Select Workload' -Options $workloadOptions -IncludeBack
    }
    else {
        $workloadResult = Show-TBMenu -Title 'Select Workload(s)' -Options $workloadOptions -MultiSelect -IncludeBack
    }

    if ($workloadResult -eq 'Back') {
        return $null
    }

    # Normalize to array
    if ($workloadResult -is [int]) {
        $selectedWorkloadIndices = @($workloadResult)
    }
    else {
        $selectedWorkloadIndices = @($workloadResult)
    }

    $allSelectedTypes = [System.Collections.ArrayList]::new()

    foreach ($wIndex in $selectedWorkloadIndices) {
        $workloadName = $workloadNames[$wIndex]
        $workloadInfo = $registry[$workloadName]
        $resourceTypes = @($workloadInfo.ResourceTypes)

        $searchTerm = $null
        if (Test-TBArrowKeySupport) {
            Write-Host ''
            $searchTerm = Read-TBUserInput -Prompt ('Filter resource types in {0} (optional)' -f $workloadName)
        }

        if ($searchTerm) {
            $searchPattern = [regex]::Escape($searchTerm)
            $resourceTypes = @(
                $resourceTypes | Where-Object {
                    $_.DisplayName -match $searchPattern -or $_.Name -match $searchPattern -or $_.ShortName -match $searchPattern
                }
            )

            if ($resourceTypes.Count -eq 0) {
                Write-Host ('  No resource types matched "{0}" in {1}.' -f $searchTerm, $workloadName) -ForegroundColor Yellow
                continue
            }
        }

        # Step 2: Pick resource types within workload
        $typeOptions = @()
        foreach ($rt in $resourceTypes) {
            $typeOptions += ('{0} ({1})' -f $rt.DisplayName, $rt.Name)
        }

        $typeResult = Show-TBMenu -Title ('Select Resource Types - {0}' -f $workloadName) -Options $typeOptions -MultiSelect -IncludeBack

        if ($typeResult -eq 'Back') {
            continue
        }

        # Normalize to array
        if ($typeResult -is [int]) {
            $selectedTypeIndices = @($typeResult)
        }
        else {
            $selectedTypeIndices = @($typeResult)
        }

        foreach ($tIndex in $selectedTypeIndices) {
            $null = $allSelectedTypes.Add($resourceTypes[$tIndex].Name)
        }
    }

    if ($allSelectedTypes.Count -eq 0) {
        return $null
    }

    # Show summary
    Write-Host ''
    Write-Host ('  Selected {0} resource type(s):' -f $allSelectedTypes.Count) -ForegroundColor Green
    foreach ($typeName in $allSelectedTypes) {
        Write-Host ('    - {0}' -f $typeName) -ForegroundColor White
    }
    Write-Host ''

    return @($allSelectedTypes)
}
