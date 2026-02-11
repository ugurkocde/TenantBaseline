#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Select-TBCatalogEntry' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-Host {}
        Mock -ModuleName TenantBaseline Test-TBArrowKeySupport { return $false }
    }

    Context 'Returns null when user goes back at workload level' {

        It 'Returns null when Back is selected at workload menu' {
            Mock -ModuleName TenantBaseline Show-TBMenu { return 'Back' }

            $result = InModuleScope TenantBaseline {
                Select-TBCatalogEntry
            }

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Returns null when user goes back at category level' {

        It 'Returns null when Back is selected at category menu' {
            # First call: workload selection returns index 0
            # Second call: category selection returns Back
            $script:callCount = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { return 0 }
                return 'Back'
            }

            $result = InModuleScope TenantBaseline {
                Select-TBCatalogEntry
            }

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Returns resource types from confirmed category' {

        It 'Returns resource type strings for a single category confirmation' {
            # First call: workload selection (index 0)
            # Second call: category single-select (index 0)
            $script:callCount = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { return 0 }
                return 0
            }
            Mock -ModuleName TenantBaseline Show-TBCatalogDetailView { return $true }

            $result = InModuleScope TenantBaseline {
                Select-TBCatalogEntry
            }

            $result | Should -Not -BeNullOrEmpty
            foreach ($rt in $result) {
                $rt | Should -Match '^microsoft\.\w+\.\w+'
            }
        }

        It 'Loops back to category menu when detail view is declined then selects Back' {
            # First call: workload (index 0)
            # Second call: category (index 0) -> detail declined
            # Third call: category (Back)
            $script:callCount = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { return 0 }
                if ($script:callCount -eq 2) { return 0 }
                return 'Back'
            }
            Mock -ModuleName TenantBaseline Show-TBCatalogDetailView { return $false }

            $result = InModuleScope TenantBaseline {
                Select-TBCatalogEntry
            }

            $result | Should -BeNullOrEmpty
        }

        It 'All returned types exist in the UTCM catalog' {
            # Select Exchange Online workload (index 1) and first category
            $script:callCount = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:callCount++
                if ($script:callCount -eq 1) { return 1 }
                return 0
            }
            Mock -ModuleName TenantBaseline Show-TBCatalogDetailView { return $true }

            $result = InModuleScope TenantBaseline {
                Select-TBCatalogEntry
            }

            $utcm = InModuleScope TenantBaseline { Get-TBUTCMCatalog }
            $utcmNames = @($utcm.Resources | ForEach-Object { $_.Name })

            foreach ($rt in $result) {
                $utcmNames | Should -Contain $rt
            }
        }
    }
}
