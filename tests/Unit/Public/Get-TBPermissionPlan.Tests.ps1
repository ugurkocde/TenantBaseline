#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-TBPermissionPlan' {

    It 'Builds a workload-based plan for ConditionalAccess' {
        $result = Get-TBPermissionPlan -Workload ConditionalAccess

        $result | Should -Not -BeNullOrEmpty
        $result.RequestedWorkloads | Should -Contain 'ConditionalAccess'
        $result.AutoGrantGraphPermissions.Count | Should -BeGreaterThan 0
    }

    It 'Builds a resource-type-based plan and resolves aliases' {
        Mock -ModuleName TenantBaseline Write-TBLog {}

        $result = Get-TBPermissionPlan -ResourceType 'microsoft.graph.conditionalAccessPolicy'

        $result.CanonicalResourceTypes | Should -Contain 'microsoft.entra.conditionalaccesspolicy'
        $result.RequestedWorkloads | Should -Contain 'ConditionalAccess'
    }

    It 'Supports MultiWorkload aggregation' {
        $result = Get-TBPermissionPlan -Workload MultiWorkload
        $result.RequestedWorkloads.Count | Should -BeGreaterThan 3
    }
}
