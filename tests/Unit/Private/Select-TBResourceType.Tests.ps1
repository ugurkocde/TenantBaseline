#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Select-TBResourceType' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-Host {}
        Mock -ModuleName TenantBaseline Read-TBUserInput { return '' }
    }

    Context 'Returns null when user goes back at workload selection' {

        It 'Returns null when Back is selected at workload level' {
            Mock -ModuleName TenantBaseline Show-TBMenu { return 'Back' }

            $result = InModuleScope TenantBaseline {
                Select-TBResourceType
            }

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Returns selected resource types' {

        It 'Returns resource type names when selections are made' {
            $script:showMenuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:showMenuCalls++
                if ($script:showMenuCalls -eq 1) {
                    # Workload selection - select first workload
                    return @(0)
                }
                else {
                    # Resource type selection - select first two
                    return @(0, 1)
                }
            }

            $result = InModuleScope TenantBaseline {
                Select-TBResourceType
            }

            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0] | Should -Match '^microsoft\.\w+\.\w+'
        }
    }
}
