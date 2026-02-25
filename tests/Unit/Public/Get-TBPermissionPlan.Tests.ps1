#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-TBPermissionPlan' {

    Context 'Workload-based plan' {

        It 'Builds a plan for ConditionalAccess' {
            $result = Get-TBPermissionPlan -Workload ConditionalAccess

            $result | Should -Not -BeNullOrEmpty
            $result.RequestedWorkloads | Should -Contain 'ConditionalAccess'
            $result.AutoGrantGraphPermissions.Count | Should -BeGreaterThan 0
        }

        It 'Supports MultiWorkload aggregation' {
            $result = Get-TBPermissionPlan -Workload MultiWorkload
            $result.RequestedWorkloads.Count | Should -BeGreaterThan 3
        }
    }

    Context 'Resource-type-based plan' {

        It 'Resolves canonical resource types from aliases' {
            Mock -ModuleName TenantBaseline Write-TBLog {}

            $result = Get-TBPermissionPlan -ResourceType 'microsoft.graph.conditionalAccessPolicy'

            $result.CanonicalResourceTypes | Should -Contain 'microsoft.entra.conditionalaccesspolicy'
            $result.RequestedWorkloads | Should -Contain 'ConditionalAccess'
        }
    }

    Context 'Workload-specific permissions' {

        It 'Includes Organization.Read.All for Teams workload' {
            $result = Get-TBPermissionPlan -Workload Teams
            $result.AutoGrantGraphPermissions | Should -Contain 'Organization.Read.All'
        }
    }
}
