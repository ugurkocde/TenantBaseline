#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-TBColorPalette' {

    Context 'Returns expected palette structure' {

        It 'Returns a hashtable' {
            $result = InModuleScope TenantBaseline {
                Get-TBColorPalette
            }

            $result | Should -BeOfType [hashtable]
        }

        It 'Contains all expected color keys' {
            $result = InModuleScope TenantBaseline {
                Get-TBColorPalette
            }

            $expectedKeys = @('Text', 'Subtext', 'Dim', 'Blue', 'Green', 'Red', 'Yellow', 'Mauve', 'Teal', 'Peach', 'Surface', 'BgSelect', 'Bold', 'Italic', 'DimStyle', 'Reset')
            foreach ($key in $expectedKeys) {
                $result.ContainsKey($key) | Should -BeTrue -Because "palette should contain key '$key'"
            }
        }

        It 'Returns string values for all keys' {
            $result = InModuleScope TenantBaseline {
                Get-TBColorPalette
            }

            foreach ($key in $result.Keys) {
                $result[$key] | Should -BeOfType [string]
            }
        }
    }
}
