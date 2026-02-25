function Get-TBPermissionPlan {
    <#
    .SYNOPSIS
        Builds a permission plan for UTCM workloads/resource types.
    .DESCRIPTION
        Returns graph permissions that can be auto-granted and manual remediation
        steps needed for providers where automatic assignment is not supported.
    .PARAMETER Workload
        One or more workload names.
    .PARAMETER ResourceType
        One or more resource types. Aliases are auto-resolved unless invalid.
    .EXAMPLE
        Get-TBPermissionPlan -Workload MultiWorkload
    .EXAMPLE
        Get-TBPermissionPlan -ResourceType microsoft.entra.conditionalaccesspolicy
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByWorkload')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByWorkload')]
        [ValidateSet('ConditionalAccess', 'EntraID', 'ExchangeOnline', 'Intune', 'Teams', 'SecurityAndCompliance', 'MultiWorkload')]
        [string[]]$Workload,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceType')]
        [string[]]$ResourceType
    )

    $catalog = Get-TBUTCMCatalog
    $profileLookup = @{}
    foreach ($profileEntry in $catalog.PermissionProfiles.PSObject.Properties) {
        $profileLookup[$profileEntry.Name] = $profileEntry.Value
    }

    $selectedWorkloads = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $resolvedResourceTypes = [System.Collections.ArrayList]::new()
    $useResourceLevelPerms = $false
    $resourceLevelPerms = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $fallbackWorkloads = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if ($PSCmdlet.ParameterSetName -eq 'ByWorkload') {
        foreach ($item in $Workload) {
            if ($item -eq 'MultiWorkload') {
                foreach ($name in $profileLookup.Keys) {
                    $null = $selectedWorkloads.Add($name)
                }
            }
            else {
                $null = $selectedWorkloads.Add($item)
            }
        }
    }
    else {
        $useResourceLevelPerms = $true
        $resourceLookup = @{}
        foreach ($resource in $catalog.Resources) {
            $resourceLookup[$resource.Name.ToLowerInvariant()] = $resource
        }

        $warningTracker = @{}
        foreach ($item in $ResourceType) {
            $resolved = Resolve-TBResourceType -ResourceType $item -WarningTracker $warningTracker
            $null = $resolvedResourceTypes.Add($resolved.CanonicalResourceType)

            $resource = $resourceLookup[$resolved.CanonicalResourceType]
            if (-not $resource) {
                continue
            }

            # Check for per-resource GraphReadPermissions first
            $hasResourcePerms = $false
            if ($resource.PSObject.Properties['GraphReadPermissions'] -and $resource.GraphReadPermissions.Count -gt 0) {
                foreach ($perm in $resource.GraphReadPermissions) {
                    $null = $resourceLevelPerms.Add($perm)
                }
                $hasResourcePerms = $true
            }

            # Determine the workload for fallback or manual steps
            $workloadName = $null
            if ($resolved.CanonicalResourceType -eq 'microsoft.entra.conditionalaccesspolicy') {
                $workloadName = 'ConditionalAccess'
            }
            elseif ($resource.WorkloadId) {
                $workloadName = $resource.WorkloadId
            }

            if ($workloadName) {
                $null = $selectedWorkloads.Add($workloadName)
                if (-not $hasResourcePerms) {
                    # No per-resource permissions; fall back to full workload profile
                    $null = $fallbackWorkloads.Add($workloadName)
                }
            }
        }
    }

    $autoGrant = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $manualSteps = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if ($useResourceLevelPerms -and $resourceLevelPerms.Count -gt 0) {
        # Add resource-level permissions
        foreach ($perm in $resourceLevelPerms) {
            $null = $autoGrant.Add($perm)
        }

        # Add workload profile permissions only for resources without per-resource data
        foreach ($name in $fallbackWorkloads) {
            $profileDetails = $profileLookup[$name]
            if (-not $profileDetails) { continue }

            foreach ($permission in @($profileDetails.AutoGrantGraphPermissions)) {
                if ($permission) { $null = $autoGrant.Add($permission) }
            }
        }

        # Always include manual steps from all relevant workloads
        foreach ($name in $selectedWorkloads) {
            $profileDetails = $profileLookup[$name]
            if (-not $profileDetails) { continue }

            foreach ($step in @($profileDetails.ManualSteps)) {
                if ($step) { $null = $manualSteps.Add($step) }
            }
        }
    }
    else {
        foreach ($name in $selectedWorkloads) {
            $profileDetails = $profileLookup[$name]
            if (-not $profileDetails) {
                continue
            }

            foreach ($permission in @($profileDetails.AutoGrantGraphPermissions)) {
                if ($permission) {
                    $null = $autoGrant.Add($permission)
                }
            }

            foreach ($step in @($profileDetails.ManualSteps)) {
                if ($step) {
                    $null = $manualSteps.Add($step)
                }
            }
        }
    }

    [PSCustomObject]@{
        PSTypeName               = 'TenantBaseline.PermissionPlan'
        GeneratedAt              = (Get-Date).ToString('o')
        CatalogSource            = $catalog.Source
        CatalogSchemaVersion     = $catalog.SchemaVersion
        RequestedWorkloads       = @($selectedWorkloads | Sort-Object)
        RequestedResourceTypes   = if ($ResourceType) { @($ResourceType) } else { @() }
        CanonicalResourceTypes   = @($resolvedResourceTypes | Sort-Object -Unique)
        AutoGrantGraphPermissions = @($autoGrant | Sort-Object)
        ManualSteps              = @($manualSteps | Sort-Object)
    }
}
