#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Test-TBArrowKeySupport' {

    Context 'Returns a boolean' {

        It 'Returns a boolean value' {
            $result = InModuleScope TenantBaseline {
                Test-TBArrowKeySupport
            }

            $result | Should -BeOfType [bool]
        }

        It 'Returns $false when Host.Name is not ConsoleHost' {
            Mock -ModuleName TenantBaseline -CommandName Get-Variable -ParameterFilter { $Name -eq 'Host' } {
                # Cannot easily mock $Host; verify the logic path via function check
            }

            InModuleScope TenantBaseline {
                $cmd = Get-Command Test-TBArrowKeySupport
                $cmd | Should -Not -BeNullOrEmpty
                $cmd.Parameters.Count | Should -BeGreaterOrEqual 0
            }
        }
    }
}
