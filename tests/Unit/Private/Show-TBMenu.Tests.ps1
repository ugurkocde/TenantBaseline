#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Show-TBMenu' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-Host {}
        Mock -ModuleName TenantBaseline Test-TBArrowKeySupport { return $false }
    }

    Context 'Single selection' {

        It 'Returns index 0 when user selects 1' {
            Mock -ModuleName TenantBaseline Read-Host { return '1' }

            $result = InModuleScope TenantBaseline {
                Show-TBMenu -Title 'Test' -Options @('Option A', 'Option B', 'Option C')
            }

            $result | Should -Be 0
        }

        It 'Returns index 2 when user selects 3' {
            Mock -ModuleName TenantBaseline Read-Host { return '3' }

            $result = InModuleScope TenantBaseline {
                Show-TBMenu -Title 'Test' -Options @('A', 'B', 'C')
            }

            $result | Should -Be 2
        }
    }

    Context 'Back option' {

        It 'Returns Back when user selects 0' {
            Mock -ModuleName TenantBaseline Read-Host { return '0' }

            $result = InModuleScope TenantBaseline {
                Show-TBMenu -Title 'Test' -Options @('A', 'B') -IncludeBack
            }

            $result | Should -Be 'Back'
        }
    }

    Context 'Quit option' {

        It 'Returns Quit when user types Q' {
            Mock -ModuleName TenantBaseline Read-Host { return 'Q' }

            $result = InModuleScope TenantBaseline {
                Show-TBMenu -Title 'Test' -Options @('A', 'B') -IncludeQuit
            }

            $result | Should -Be 'Quit'
        }

        It 'Returns Quit when user types lowercase q' {
            Mock -ModuleName TenantBaseline Read-Host { return 'q' }

            $result = InModuleScope TenantBaseline {
                Show-TBMenu -Title 'Test' -Options @('A', 'B') -IncludeQuit
            }

            $result | Should -Be 'Quit'
        }
    }

    Context 'Multi-select' {

        It 'Returns multiple indices for comma-separated input' {
            Mock -ModuleName TenantBaseline Read-Host { return '1,3' }

            $result = InModuleScope TenantBaseline {
                Show-TBMenu -Title 'Test' -Options @('A', 'B', 'C') -MultiSelect
            }

            $result | Should -HaveCount 2
            $result[0] | Should -Be 0
            $result[1] | Should -Be 2
        }

        It 'Deduplicates repeated selections' {
            Mock -ModuleName TenantBaseline Read-Host { return '1,1,3' }

            $result = InModuleScope TenantBaseline {
                Show-TBMenu -Title 'Test' -Options @('A', 'B', 'C') -MultiSelect
            }

            $result | Should -HaveCount 2
            $result[0] | Should -Be 0
            $result[1] | Should -Be 2
        }

        It 'Returns all indices when user types A' {
            Mock -ModuleName TenantBaseline Read-Host { return 'A' }

            $result = InModuleScope TenantBaseline {
                Show-TBMenu -Title 'Test' -Options @('X', 'Y', 'Z') -MultiSelect
            }

            $result | Should -HaveCount 3
            $result[0] | Should -Be 0
            $result[1] | Should -Be 1
            $result[2] | Should -Be 2
        }
    }

    Context 'Invalid input retries' {

        It 'Retries on invalid then accepts valid input' {
            $script:callCount = 0
            Mock -ModuleName TenantBaseline Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { return 'invalid' }
                return '2'
            }

            $result = InModuleScope TenantBaseline {
                Show-TBMenu -Title 'Test' -Options @('A', 'B')
            }

            $result | Should -Be 1
        }
    }
}
