function Install-TBServicePrincipal {
    <#
    .SYNOPSIS
        Provisions the UTCM service principal in the tenant.
    .DESCRIPTION
        Creates the Microsoft UTCM first-party service principal
        (AppId: 03b07b79-c5bc-4b5e-9bfa-13acf4a99998) in the tenant and
        grants all workload permissions. This is a one-time setup step
        required for monitors and snapshots to execute.
        Requires Global Administrator or Application Administrator role.
    .PARAMETER SkipPermissions
        If specified, skips granting workload permissions after creating the SP.
    .EXAMPLE
        Install-TBServicePrincipal
        Creates the SP and grants all workload permissions.
    .EXAMPLE
        Install-TBServicePrincipal -SkipPermissions
        Creates the SP without granting permissions.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter()]
        [switch]$SkipPermissions
    )

    $null = Test-TBGraphConnection

    $appId = $script:UTCMAppId
    $workloads = @('ConditionalAccess', 'EntraID', 'ExchangeOnline', 'Intune', 'Teams', 'SecurityAndCompliance')

    $invokePermissionGrantSweep = {
        param(
            [Parameter(Mandatory = $true)]
            [string[]]$Workloads
        )

        $manualSteps = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $missingAssignments = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $failedAssignments = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        foreach ($workload in $Workloads) {
            $grantResult = Grant-TBServicePrincipalPermission -Workload $workload -Confirm:$false

            foreach ($step in @($grantResult.ManualSteps)) {
                if ($step) {
                    $null = $manualSteps.Add($step)
                }
            }

            foreach ($permission in @($grantResult.PermissionsMissingInTenant)) {
                if ($permission) {
                    $null = $missingAssignments.Add(('{0}: {1}' -f $workload, $permission))
                }
            }

            foreach ($permission in @($grantResult.PermissionsFailedToGrant)) {
                if ($permission) {
                    $null = $failedAssignments.Add(('{0}: {1}' -f $workload, $permission))
                }
            }
        }

        [PSCustomObject]@{
            ManualSteps = @($manualSteps | Sort-Object)
            Missing     = @($missingAssignments | Sort-Object)
            Failed      = @($failedAssignments | Sort-Object)
        }
    }

    # Check if already exists
    $existing = $null
    try {
        $filterUri = "$(Get-TBGraphBaseUri)/v1.0/servicePrincipals?`$filter=appId eq '$appId'"
        $response = Invoke-TBGraphRequest -Uri $filterUri -Method 'GET'

        $items = $null
        if ($response -is [hashtable] -and $response.ContainsKey('value')) {
            $items = $response['value']
        }
        elseif ($response.PSObject.Properties['value']) {
            $items = $response.value
        }

        if ($items -and @($items).Count -gt 0) {
            $existing = $items[0]
        }
    }
    catch {
        Write-TBLog -Message ('Error checking for existing SP: {0}' -f $_) -Level 'Warning'
    }

    if ($existing) {
        $spId = if ($existing -is [hashtable]) { $existing['id'] } else { $existing.id }
        Write-Output ('UTCM service principal already exists (ID: {0})' -f $spId)

        $grantSummary = [PSCustomObject]@{
            ManualSteps = @()
            Missing     = @()
            Failed      = @()
        }

        if (-not $SkipPermissions) {
            Write-Output 'Granting all workload permissions...'
            $grantSummary = & $invokePermissionGrantSweep -Workloads $workloads

            if ($grantSummary.Missing.Count -eq 0 -and $grantSummary.Failed.Count -eq 0) {
                Write-Output 'All auto-grant Graph workload permissions applied.'
            }
            else {
                Write-Output 'Permission grant completed with issues. Review details below:'
                foreach ($item in $grantSummary.Missing) {
                    Write-Output ('  - Missing app role in tenant: {0}' -f $item)
                }
                foreach ($item in $grantSummary.Failed) {
                    Write-Output ('  - Failed to grant app role: {0}' -f $item)
                }
            }

            if ($grantSummary.ManualSteps.Count -gt 0) {
                Write-Output 'Manual follow-up required for some workloads:'
                foreach ($step in $grantSummary.ManualSteps) {
                    Write-Output ('  - {0}' -f $step)
                }
            }
        }

        return [PSCustomObject]@{
            PSTypeName       = 'TenantBaseline.ServicePrincipal'
            Id               = $spId
            AppId            = $appId
            AlreadyExisted   = $true
            PermissionIssuesPresent = ($grantSummary.Missing.Count -gt 0 -or $grantSummary.Failed.Count -gt 0)
            PermissionsMissingInTenant = @($grantSummary.Missing)
            PermissionsFailedToGrant   = @($grantSummary.Failed)
            ManualSteps = @($grantSummary.ManualSteps)
        }
    }

    if ($PSCmdlet.ShouldProcess('UTCM Service Principal', 'Create in tenant and grant all workload permissions')) {
        Write-TBLog -Message 'Creating UTCM service principal'

        $body = @{
            appId = $appId
        }

        $createUri = "$(Get-TBGraphBaseUri)/v1.0/servicePrincipals"
        $result = Invoke-TBGraphRequest -Uri $createUri -Method 'POST' -Body $body

        $spId = if ($result -is [hashtable]) { $result['id'] } else { $result.id }

        Write-TBLog -Message ('UTCM service principal created (ID: {0})' -f $spId)
        Write-Output ('UTCM service principal created successfully (ID: {0})' -f $spId)

        $grantSummary = [PSCustomObject]@{
            ManualSteps = @()
            Missing     = @()
            Failed      = @()
        }

        if (-not $SkipPermissions) {
            Write-Output 'Granting all workload permissions...'
            $grantSummary = & $invokePermissionGrantSweep -Workloads $workloads

            if ($grantSummary.Missing.Count -eq 0 -and $grantSummary.Failed.Count -eq 0) {
                Write-Output 'All auto-grant Graph workload permissions applied.'
            }
            else {
                Write-Output 'Permission grant completed with issues. Review details below:'
                foreach ($item in $grantSummary.Missing) {
                    Write-Output ('  - Missing app role in tenant: {0}' -f $item)
                }
                foreach ($item in $grantSummary.Failed) {
                    Write-Output ('  - Failed to grant app role: {0}' -f $item)
                }
            }

            if ($grantSummary.ManualSteps.Count -gt 0) {
                Write-Output 'Manual follow-up required for some workloads:'
                foreach ($step in $grantSummary.ManualSteps) {
                    Write-Output ('  - {0}' -f $step)
                }
            }
        }

        return [PSCustomObject]@{
            PSTypeName       = 'TenantBaseline.ServicePrincipal'
            Id               = $spId
            AppId            = $appId
            AlreadyExisted   = $false
            PermissionIssuesPresent = ($grantSummary.Missing.Count -gt 0 -or $grantSummary.Failed.Count -gt 0)
            PermissionsMissingInTenant = @($grantSummary.Missing)
            PermissionsFailedToGrant   = @($grantSummary.Failed)
            ManualSteps = @($grantSummary.ManualSteps)
        }
    }
}
