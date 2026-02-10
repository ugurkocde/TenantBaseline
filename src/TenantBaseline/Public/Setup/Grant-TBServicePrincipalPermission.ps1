function Grant-TBServicePrincipalPermission {
    <#
    .SYNOPSIS
        Grants UTCM service principal permissions.
    .DESCRIPTION
        Uses a resource/workload-aware permission plan. Auto-grants assignable
        Microsoft Graph app roles and returns guided manual remediation steps for
        provider-specific permissions that can't be automatically granted.
    .PARAMETER Workload
        The workload to grant permissions for.
    .PARAMETER ResourceType
        One or more resource types to derive a permission plan from.
    .PARAMETER PlanOnly
        Returns the permission plan without granting permissions.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ByWorkload')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByWorkload')]
        [ValidateSet('ConditionalAccess', 'EntraID', 'ExchangeOnline', 'Intune', 'Teams', 'SecurityAndCompliance', 'SharePoint', 'MultiWorkload')]
        [string]$Workload,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByResourceType')]
        [string[]]$ResourceType,

        [Parameter()]
        [switch]$PlanOnly
    )

    $null = Test-TBGraphConnection

    if ($PSCmdlet.ParameterSetName -eq 'ByWorkload') {
        $plan = Get-TBPermissionPlan -Workload $Workload
    }
    else {
        $plan = Get-TBPermissionPlan -ResourceType $ResourceType
    }

    if ($PlanOnly) {
        return $plan
    }

    $requiredPermissions = @($plan.AutoGrantGraphPermissions)
    try {
        $context = Get-MgContext
    }
    catch {
        $context = $null
    }

    if ($requiredPermissions.Count -gt 0 -and $context -and $context.Scopes) {
        $scopeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($scope in @($context.Scopes)) {
            if ($scope) {
                $null = $scopeSet.Add($scope)
            }
        }

        if (-not $scopeSet.Contains('Application.ReadWrite.All')) {
            throw 'Granting UTCM service principal permissions requires Application.ReadWrite.All. Reconnect using Connect-TBTenant -Scenario Setup.'
        }
    }

    # Find the UTCM service principal
    $appId = $script:UTCMAppId
    $filterUri = "$(Get-TBGraphBaseUri)/v1.0/servicePrincipals?`$filter=appId eq '$appId'"
    $spResponse = Invoke-TBGraphRequest -Uri $filterUri -Method 'GET'

    $spItems = $null
    if ($spResponse -is [hashtable] -and $spResponse.ContainsKey('value')) {
        $spItems = $spResponse['value']
    }
    elseif ($spResponse.PSObject.Properties['value']) {
        $spItems = $spResponse.value
    }

    if (-not $spItems -or @($spItems).Count -eq 0) {
        throw 'UTCM service principal not found. Run Install-TBServicePrincipal first.'
    }

    $sp = $spItems[0]
    $spId = if ($sp -is [hashtable]) { $sp['id'] } else { $sp.id }

    # Find Microsoft Graph service principal to get role IDs
    $graphAppId = '00000003-0000-0000-c000-000000000000'
    $graphFilterUri = "$(Get-TBGraphBaseUri)/v1.0/servicePrincipals?`$filter=appId eq '$graphAppId'"
    $graphSpResponse = Invoke-TBGraphRequest -Uri $graphFilterUri -Method 'GET'

    $graphItems = $null
    if ($graphSpResponse -is [hashtable] -and $graphSpResponse.ContainsKey('value')) {
        $graphItems = $graphSpResponse['value']
    }
    elseif ($graphSpResponse.PSObject.Properties['value']) {
        $graphItems = $graphSpResponse.value
    }

    if (-not $graphItems -or @($graphItems).Count -eq 0) {
        throw 'Microsoft Graph service principal not found in tenant.'
    }

    $graphSp = $graphItems[0]
    $graphSpId = if ($graphSp -is [hashtable]) { $graphSp['id'] } else { $graphSp.id }
    $appRoles = if ($graphSp -is [hashtable]) { $graphSp['appRoles'] } else { $graphSp.appRoles }

    # Build a set of already-assigned Graph app roles for the UTCM SP so we can
    # avoid duplicate POST attempts that often surface as generic BadRequest.
    $existingGraphRoleAssignments = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $assignmentUri = "$(Get-TBGraphBaseUri)/v1.0/servicePrincipals/{0}/appRoleAssignments" -f $spId
        $assignments = Invoke-TBGraphPagedRequest -Uri $assignmentUri
        foreach ($assignment in @($assignments)) {
            $assignmentResourceId = if ($assignment -is [hashtable]) { $assignment['resourceId'] } else { $assignment.resourceId }
            $assignmentRoleId = if ($assignment -is [hashtable]) { $assignment['appRoleId'] } else { $assignment.appRoleId }
            if (-not $assignmentResourceId -or -not $assignmentRoleId) {
                continue
            }

            if ($assignmentResourceId.ToString() -eq $graphSpId.ToString()) {
                $null = $existingGraphRoleAssignments.Add($assignmentRoleId.ToString())
            }
        }
    }
    catch {
        Write-TBLog -Message ('Unable to pre-load existing app role assignments: {0}' -f $_.Exception.Message) -Level 'Warning'
    }

    $grantedCount = 0
    $alreadyGrantedCount = 0
    $missingRoles = [System.Collections.ArrayList]::new()
    $failedRoles = [System.Collections.ArrayList]::new()

    foreach ($permission in $requiredPermissions) {
        $role = $null
        foreach ($appRole in $appRoles) {
            $roleValue = if ($appRole -is [hashtable]) { $appRole['value'] } else { $appRole.value }
            if ($roleValue -eq $permission) {
                $role = $appRole
                break
            }
        }

        if (-not $role) {
            Write-TBLog -Message ('App role not found for permission: {0}' -f $permission) -Level 'Warning'
            $null = $missingRoles.Add($permission)
            continue
        }

        $roleId = if ($role -is [hashtable]) { $role['id'] } else { $role.id }
        if ($roleId -and $existingGraphRoleAssignments.Contains($roleId.ToString())) {
            Write-TBLog -Message ('Permission already granted: {0}' -f $permission)
            $alreadyGrantedCount++
            continue
        }

        if ($PSCmdlet.ShouldProcess($permission, 'Grant permission to UTCM service principal')) {
            try {
                $body = @{
                    principalId = $spId
                    resourceId  = $graphSpId
                    appRoleId   = $roleId
                }

                $grantUri = "$(Get-TBGraphBaseUri)/v1.0/servicePrincipals/{0}/appRoleAssignments" -f $spId
                $null = Invoke-TBGraphRequest -Uri $grantUri -Method 'POST' -Body $body
                Write-TBLog -Message ('Granted permission: {0}' -f $permission)
                $grantedCount++
            }
            catch {
                $errorMsg = $_.Exception.Message
                if ($errorMsg -match 'already exists') {
                    Write-TBLog -Message ('Permission already granted: {0}' -f $permission)
                    $alreadyGrantedCount++
                }
                else {
                    Write-TBLog -Message ('Failed to grant {0}: {1}' -f $permission, $errorMsg) -Level 'Warning'
                    if (-not $failedRoles.Contains($permission)) {
                        $null = $failedRoles.Add($permission)
                    }
                }
            }
        }
    }

    [PSCustomObject]@{
        PSTypeName                  = 'TenantBaseline.PermissionGrantResult'
        Workloads                   = $plan.RequestedWorkloads
        ResourceTypes               = $plan.CanonicalResourceTypes
        PermissionsPlanned          = $requiredPermissions.Count
        PermissionsGranted          = $grantedCount
        PermissionsAlreadyGranted   = $alreadyGrantedCount
        PermissionsMissingInTenant  = @($missingRoles)
        PermissionsFailedToGrant    = @($failedRoles)
        ManualSteps                 = $plan.ManualSteps
        CompatibilityNotes          = $plan.CompatibilityNotes
    }
}
