#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Baseline catalog contract' {

    It 'Loads catalog with expected shape' {
        $catalog = InModuleScope TenantBaseline { Get-TBBaselineCatalog -ForceReload }

        $catalog.SchemaVersion | Should -Be '1.2'
        $catalog.Source | Should -BeLike '*Maester*'
        @($catalog.Categories).Count | Should -Be 20
    }

    It 'Each category has required fields' {
        $catalog = InModuleScope TenantBaseline { Get-TBBaselineCatalog }

        foreach ($cat in $catalog.Categories) {
            $cat.Id | Should -Not -BeNullOrEmpty
            $cat.Name | Should -Not -BeNullOrEmpty
            $cat.Description | Should -Not -BeNullOrEmpty
            $cat.Framework | Should -BeIn @('EIDSCA', 'ORCA', 'CIS', 'CISA', 'Maester')
            $cat.Workload | Should -BeIn @('Entra ID', 'Exchange Online', 'Teams')
            $cat.Severity | Should -BeIn @('High', 'Medium', 'Low', 'Info')
            @($cat.ResourceTypes).Count | Should -BeGreaterThan 0
            @($cat.Tests).Count | Should -BeGreaterThan 0
        }
    }

    It 'Each test entry has required fields' {
        $catalog = InModuleScope TenantBaseline { Get-TBBaselineCatalog }

        foreach ($cat in $catalog.Categories) {
            foreach ($test in $cat.Tests) {
                $test.TestId | Should -Not -BeNullOrEmpty
                $test.ResourceType | Should -Not -BeNullOrEmpty
                $test.Property | Should -Not -BeNullOrEmpty
                $test.RecommendedValue | Should -Not -BeNullOrEmpty
                $test.Description | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'Each test ResourceType belongs to its parent category' {
        $catalog = InModuleScope TenantBaseline { Get-TBBaselineCatalog }

        foreach ($cat in $catalog.Categories) {
            $catTypes = @($cat.ResourceTypes)
            foreach ($test in $cat.Tests) {
                $catTypes | Should -Contain $test.ResourceType
            }
        }
    }

    It 'Each category has BaselineResources with required fields' {
        $catalog = InModuleScope TenantBaseline { Get-TBBaselineCatalog }

        foreach ($cat in $catalog.Categories) {
            @($cat.BaselineResources).Count | Should -BeGreaterThan 0
            foreach ($br in $cat.BaselineResources) {
                $br.ResourceType | Should -Not -BeNullOrEmpty
                $br.Properties | Should -Not -BeNullOrEmpty
                $br.Properties.IsSingleInstance | Should -Be 'Yes'
            }
        }
    }

    It 'Each BaselineResource type belongs to its parent category ResourceTypes' {
        $catalog = InModuleScope TenantBaseline { Get-TBBaselineCatalog }

        foreach ($cat in $catalog.Categories) {
            $catTypes = @($cat.ResourceTypes)
            foreach ($br in $cat.BaselineResources) {
                $catTypes | Should -Contain $br.ResourceType
            }
        }
    }

    It 'All resource types exist in the UTCM catalog' {
        $catalog = InModuleScope TenantBaseline { Get-TBBaselineCatalog }
        $utcm = InModuleScope TenantBaseline { Get-TBUTCMCatalog }
        $utcmNames = @($utcm.Resources | ForEach-Object { $_.Name })

        foreach ($cat in $catalog.Categories) {
            foreach ($rt in $cat.ResourceTypes) {
                $utcmNames | Should -Contain $rt
            }
        }
    }

    It 'Has categories across all expected workloads' {
        $catalog = InModuleScope TenantBaseline { Get-TBBaselineCatalog }
        $workloads = @($catalog.Categories | ForEach-Object { $_.Workload } | Sort-Object -Unique)

        $workloads | Should -Contain 'Entra ID'
        $workloads | Should -Contain 'Exchange Online'
        $workloads | Should -Contain 'Teams'
    }

    It 'Caches catalog on subsequent calls' {
        InModuleScope TenantBaseline { $script:TBBaselineCatalog = $null }
        $first = InModuleScope TenantBaseline { Get-TBBaselineCatalog }
        $second = InModuleScope TenantBaseline { Get-TBBaselineCatalog }

        [object]::ReferenceEquals($first, $second) | Should -BeTrue
    }
}
