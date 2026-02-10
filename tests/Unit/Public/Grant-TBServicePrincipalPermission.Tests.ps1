#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Grant-TBServicePrincipalPermission' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
        Mock -ModuleName TenantBaseline Get-MgContext { return $null }
        Mock -ModuleName TenantBaseline Get-TBGraphBaseUri { return 'https://graph.microsoft.com' }
        Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { throw 'Should not be called in this test path.' }
        Mock -ModuleName TenantBaseline Get-TBPermissionPlan {
            [PSCustomObject]@{
                RequestedWorkloads        = @('ConditionalAccess')
                CanonicalResourceTypes    = @('microsoft.entra.conditionalaccesspolicy')
                AutoGrantGraphPermissions = @('Policy.Read.All', 'Policy.ReadWrite.ConditionalAccess')
                ManualSteps               = @('Manual step')
                CompatibilityNotes        = @()
            }
        }
    }

    Context 'Grants permissions for a workload' {

        It 'Calls the API to grant permissions for ConditionalAccess workload' {
            $spListData = Get-Content -Path (Join-Path $fixturesPath 'ServicePrincipalList.json') -Raw | ConvertFrom-Json

            $graphSpResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id       = 'graph-sp-id-001'
                        appId    = '00000003-0000-0000-c000-000000000000'
                        appRoles = @(
                            [PSCustomObject]@{ id = 'role-policy-read'; value = 'Policy.Read.All' }
                            [PSCustomObject]@{ id = 'role-ca-readwrite'; value = 'Policy.ReadWrite.ConditionalAccess' }
                        )
                    }
                )
            }

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match '03b07b79') { return $spListData }
                if ($Uri -match '00000003-0000-0000-c000-000000000000') { return $graphSpResponse }
                return [PSCustomObject]@{ id = 'assignment-001' }
            }

            $result = Grant-TBServicePrincipalPermission -Workload 'ConditionalAccess' -Confirm:$false

            $result.PermissionsGranted | Should -Be 2
            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'appRoleAssignments'
            } -Times 2
        }
    }

    Context 'Throws when UTCM SP is not found' {

        It 'Throws an error when the UTCM SP does not exist' {
            $emptyResponse = Get-Content -Path (Join-Path $fixturesPath 'EmptyResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $emptyResponse }

            { Grant-TBServicePrincipalPermission -Workload 'ConditionalAccess' -Confirm:$false } | Should -Throw '*not found*'
        }
    }

    Context 'Supports -WhatIf and -PlanOnly' {

        It 'Does not grant permissions when -WhatIf is used' {
            $spListData = Get-Content -Path (Join-Path $fixturesPath 'ServicePrincipalList.json') -Raw | ConvertFrom-Json

            $graphSpResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id       = 'graph-sp-id-001'
                        appId    = '00000003-0000-0000-c000-000000000000'
                        appRoles = @(
                            [PSCustomObject]@{ id = 'role-policy-read'; value = 'Policy.Read.All' }
                        )
                    }
                )
            }

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match '03b07b79') { return $spListData }
                if ($Uri -match '00000003-0000-0000-c000-000000000000') { return $graphSpResponse }
                return [PSCustomObject]@{ id = 'assignment' }
            }

            Grant-TBServicePrincipalPermission -Workload 'ConditionalAccess' -WhatIf

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'appRoleAssignments'
            } -Times 0 -Exactly
        }

        It 'Returns plan without calling Graph when PlanOnly is used' {
            $result = Grant-TBServicePrincipalPermission -Workload 'ConditionalAccess' -PlanOnly
            $result.AutoGrantGraphPermissions | Should -Contain 'Policy.Read.All'

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }

    Context 'Scope validation' {

        It 'Throws when Application.ReadWrite.All is missing for auto-grant operations' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                [PSCustomObject]@{
                    Scopes = @('ConfigurationMonitoring.ReadWrite.All')
                }
            }

            { Grant-TBServicePrincipalPermission -Workload 'ConditionalAccess' -Confirm:$false } |
                Should -Throw '*Application.ReadWrite.All*'
        }
    }

    Context 'Existing assignment detection' {

        It 'Treats pre-existing app role assignments as already granted without POST' {
            $spListData = Get-Content -Path (Join-Path $fixturesPath 'ServicePrincipalList.json') -Raw | ConvertFrom-Json

            $graphSpResponse = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        id       = 'graph-sp-id-001'
                        appId    = '00000003-0000-0000-c000-000000000000'
                        appRoles = @(
                            [PSCustomObject]@{ id = 'role-policy-read'; value = 'Policy.Read.All' }
                            [PSCustomObject]@{ id = 'role-ca-readwrite'; value = 'Policy.ReadWrite.ConditionalAccess' }
                        )
                    }
                )
            }

            $existingAssignments = [PSCustomObject]@{
                value = @(
                    [PSCustomObject]@{
                        resourceId = 'graph-sp-id-001'
                        appRoleId  = 'role-policy-read'
                    }
                )
            }

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match '03b07b79') { return $spListData }
                if ($Uri -match '00000003-0000-0000-c000-000000000000') { return $graphSpResponse }
                if ($Uri -match 'appRoleAssignments' -and $Method -eq 'GET') { return $existingAssignments }
                return [PSCustomObject]@{ id = 'assignment-001' }
            }

            $result = Grant-TBServicePrincipalPermission -Workload 'ConditionalAccess' -Confirm:$false

            $result.PermissionsAlreadyGranted | Should -Be 1
            $result.PermissionsGranted | Should -Be 1

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'appRoleAssignments'
            } -Times 1
        }
    }
}
