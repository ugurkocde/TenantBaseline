#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Install-TBServicePrincipal' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
        Mock -ModuleName TenantBaseline Grant-TBServicePrincipalPermission {
            [PSCustomObject]@{
                ManualSteps              = @()
                PermissionsMissingInTenant = @()
                PermissionsFailedToGrant = @()
            }
        }
    }

    Context 'Service principal already exists' {

        It 'Returns existing SP without creating a new one' {
            $spListData = Get-Content -Path (Join-Path $fixturesPath 'ServicePrincipalList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $spListData }

            $result = Install-TBServicePrincipal -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be '9c0d1e2f-3456-7890-abcd-ef0123456789'
            $result.AlreadyExisted | Should -BeTrue
            $result.PermissionIssuesPresent | Should -BeFalse
        }

        It 'Grants all workload permissions by default' {
            $spListData = Get-Content -Path (Join-Path $fixturesPath 'ServicePrincipalList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $spListData }

            $null = Install-TBServicePrincipal -Confirm:$false

            Should -Invoke -CommandName Grant-TBServicePrincipalPermission -ModuleName TenantBaseline -Times 6 -Exactly
        }

        It 'Skips permissions when SkipPermissions is specified' {
            $spListData = Get-Content -Path (Join-Path $fixturesPath 'ServicePrincipalList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $spListData }

            $null = Install-TBServicePrincipal -SkipPermissions -Confirm:$false

            Should -Invoke -CommandName Grant-TBServicePrincipalPermission -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }

    Context 'Service principal does not exist' {

        It 'Creates a new SP and returns the result' {
            $emptyResponse = Get-Content -Path (Join-Path $fixturesPath 'EmptyResponse.json') -Raw | ConvertFrom-Json
            $createResponse = [PSCustomObject]@{
                id    = 'new-sp-id-001'
                appId = '03b07b79-c5bc-4b5e-9bfa-13acf4a99998'
            }

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Method -eq 'GET') {
                    return $emptyResponse
                }
                return $createResponse
            }

            $result = Install-TBServicePrincipal -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be 'new-sp-id-001'
            $result.AlreadyExisted | Should -BeFalse
            $result.PermissionIssuesPresent | Should -BeFalse
        }

        It 'Grants all workload permissions after creating SP' {
            $emptyResponse = Get-Content -Path (Join-Path $fixturesPath 'EmptyResponse.json') -Raw | ConvertFrom-Json
            $createResponse = [PSCustomObject]@{
                id    = 'new-sp-id-001'
                appId = '03b07b79-c5bc-4b5e-9bfa-13acf4a99998'
            }

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Method -eq 'GET') {
                    return $emptyResponse
                }
                return $createResponse
            }

            $null = Install-TBServicePrincipal -Confirm:$false

            Should -Invoke -CommandName Grant-TBServicePrincipalPermission -ModuleName TenantBaseline -Times 6 -Exactly
        }
    }

    Context 'Permission issues are surfaced in result object' {

        It 'Marks permission issues when grant contains missing or failed assignments' {
            $spListData = Get-Content -Path (Join-Path $fixturesPath 'ServicePrincipalList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $spListData }
            Mock -ModuleName TenantBaseline Grant-TBServicePrincipalPermission {
                [PSCustomObject]@{
                    ManualSteps                = @()
                    PermissionsMissingInTenant = @('Policy.Read.All')
                    PermissionsFailedToGrant   = @('Group.Read.All')
                }
            }

            $result = Install-TBServicePrincipal -Confirm:$false

            $result.PermissionIssuesPresent | Should -BeTrue
            $result.PermissionsMissingInTenant.Count | Should -BeGreaterThan 0
            $result.PermissionsFailedToGrant.Count | Should -BeGreaterThan 0
        }
    }

    Context 'Supports -WhatIf' {

        It 'Does not create SP when -WhatIf is used' {
            $emptyResponse = Get-Content -Path (Join-Path $fixturesPath 'EmptyResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $emptyResponse }

            Install-TBServicePrincipal -WhatIf

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -ParameterFilter {
                $Method -eq 'POST'
            } -Times 0 -Exactly
        }
    }
}
