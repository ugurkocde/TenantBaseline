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
        [ValidateSet('ConditionalAccess', 'EntraID', 'ExchangeOnline', 'Intune', 'Teams', 'SecurityAndCompliance', 'SharePoint', 'MultiWorkload')]
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

            if ($resolved.CanonicalResourceType -eq 'microsoft.entra.conditionalaccesspolicy') {
                $null = $selectedWorkloads.Add('ConditionalAccess')
            }
            elseif ($resource.WorkloadId -eq 'EntraID') {
                $null = $selectedWorkloads.Add('EntraID')
            }
            elseif ($resource.WorkloadId -eq 'ExchangeOnline') {
                $null = $selectedWorkloads.Add('ExchangeOnline')
            }
            elseif ($resource.WorkloadId -eq 'Intune') {
                $null = $selectedWorkloads.Add('Intune')
            }
            elseif ($resource.WorkloadId -eq 'Teams') {
                $null = $selectedWorkloads.Add('Teams')
            }
            elseif ($resource.WorkloadId -eq 'SecurityAndCompliance') {
                $null = $selectedWorkloads.Add('SecurityAndCompliance')
            }
        }
    }

    $autoGrant = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $manualSteps = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $compatibilityNotes = [System.Collections.ArrayList]::new()

    foreach ($name in $selectedWorkloads) {
        if ($name -eq 'SharePoint') {
            $null = $compatibilityNotes.Add('SharePoint workload mapping is retained for backward compatibility. UTCM canonical schema currently does not expose a dedicated SharePoint resource namespace in this module catalog snapshot.')
            continue
        }

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
        CompatibilityNotes       = @($compatibilityNotes)
    }
}
