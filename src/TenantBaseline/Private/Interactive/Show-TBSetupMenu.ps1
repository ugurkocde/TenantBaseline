function Invoke-TBSetupAction {
    <#
    .SYNOPSIS
        Executes a single setup/permissions action by index.
    .DESCRIPTION
        Contains the action logic extracted from Show-TBSetupMenu's switch block.
        Called by both the classic submenu loop and the accordion direct-action path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ActionIndex
    )

    switch ($ActionIndex) {
        0 { # Install service principal
            Write-Host ''
            Write-Host '  -- Install UTCM Service Principal --' -ForegroundColor Cyan
            Write-Host '  This requires Global Administrator or Application Administrator role.' -ForegroundColor Yellow
            Write-Host ''

            $confirmed = Read-TBUserInput -Prompt 'Install the UTCM service principal and grant all workload permissions?' -Confirm
            if (-not $confirmed) { return }

            try {
                $result = Install-TBServicePrincipal -Confirm:$false
                Write-Host ''
                Write-Host ('  Service Principal ID: {0}' -f $result.Id) -ForegroundColor Green
                if ($result.AlreadyExisted) {
                    Write-Host '  (Already existed)' -ForegroundColor Yellow
                }
                else {
                    Write-Host '  Successfully created.' -ForegroundColor Green
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        1 { # Check service principal status
            Write-Host ''
            Write-Host '  -- Service Principal Status --' -ForegroundColor Cyan
            Write-Host ''

            try {
                $exists = Test-TBServicePrincipal
                if ($exists) {
                    Write-Host '  UTCM service principal: INSTALLED' -ForegroundColor Green
                }
                else {
                    Write-Host '  UTCM service principal: NOT FOUND' -ForegroundColor Red
                    Write-Host '  Run "Install UTCM service principal" to set it up.' -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
        2 { # Grant workload permissions
            Write-Host ''
            Write-Host '  -- Grant Workload Permissions --' -ForegroundColor Cyan

            $workloadOptions = @(
                'ConditionalAccess'
                'EntraID'
                'ExchangeOnline'
                'Intune'
                'Teams'
                'SecurityAndCompliance'
                'SharePoint (compatibility only)'
                'MultiWorkload (all graph permissions)'
            )

            $selected = Show-TBMenu -Title 'Select Workload' -Options $workloadOptions -IncludeBack
            if ($selected -eq 'Back') { return }

            $workloadNames = @('ConditionalAccess', 'EntraID', 'ExchangeOnline', 'Intune', 'Teams', 'SecurityAndCompliance', 'SharePoint', 'MultiWorkload')
            $workload = $workloadNames[$selected]

            $confirmed = Read-TBUserInput -Prompt ('Grant {0} permissions to the UTCM service principal?' -f $workload) -Confirm
            if (-not $confirmed) { return }

            try {
                $result = Grant-TBServicePrincipalPermission -Workload $workload -Confirm:$false
                Write-Host ''

                $hasIssues = (@($result.PermissionsMissingInTenant).Count -gt 0) -or (@($result.PermissionsFailedToGrant).Count -gt 0)
                if ($hasIssues) {
                    Write-Host ('  Permission grant completed with issues for: {0}' -f $workload) -ForegroundColor Yellow
                    foreach ($item in @($result.PermissionsMissingInTenant)) {
                        Write-Host ('  Missing app role in tenant: {0}' -f $item) -ForegroundColor Yellow
                    }
                    foreach ($item in @($result.PermissionsFailedToGrant)) {
                        Write-Host ('  Failed to grant app role: {0}' -f $item) -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Host ('  Permissions granted for: {0}' -f $workload) -ForegroundColor Green
                }

                if (@($result.ManualSteps).Count -gt 0) {
                    Write-Host '  Manual follow-up required:' -ForegroundColor Yellow
                    foreach ($step in @($result.ManualSteps)) {
                        Write-Host ('  - {0}' -f $step) -ForegroundColor Yellow
                    }
                }
            }
            catch {
                Write-Host ('  Error: {0}' -f $_.Exception.Message) -ForegroundColor Red
            }

            Read-Host -Prompt '  Press Enter to continue'
        }
    }
}

function Show-TBSetupMenu {
    <#
    .SYNOPSIS
        Displays the setup and permissions submenu.
    .DESCRIPTION
        Interactive menu for installing the UTCM service principal, checking
        its status, and granting workload permissions.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$DirectAction = -1
    )

    if ($DirectAction -ge 0) {
        Invoke-TBSetupAction -ActionIndex $DirectAction
        return
    }

    while ($true) {
        Clear-Host
        Write-TBMenuHeader -Subtitle 'Setup and Permissions'

        $options = @(
            'Install UTCM service principal'
            'Check service principal status'
            'Grant workload permissions'
        )

        $choice = Show-TBMenu -Title 'Setup and Permissions' -Options $options -IncludeBack
        if ($choice -eq 'Back') { return }

        Invoke-TBSetupAction -ActionIndex $choice
    }
}
