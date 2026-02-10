#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Write-TBGradient' {

    Context 'Get-TBGradientString' {

        It 'Returns a string' {
            $result = InModuleScope TenantBaseline {
                Get-TBGradientString -Text 'Hello' -StartRGB @(255, 0, 0) -EndRGB @(0, 0, 255)
            }

            $result | Should -BeOfType [string]
        }

        It 'Returns empty string for empty input' {
            $result = InModuleScope TenantBaseline {
                Get-TBGradientString -Text '' -StartRGB @(255, 0, 0) -EndRGB @(0, 0, 255)
            }

            $result | Should -Be ''
        }

        It 'Contains the original characters in the output' {
            $result = InModuleScope TenantBaseline {
                Get-TBGradientString -Text 'AB' -StartRGB @(100, 100, 100) -EndRGB @(200, 200, 200)
            }

            $result | Should -Match 'A'
            $result | Should -Match 'B'
        }
    }

    Context 'Get-TBGradientLine' {

        It 'Returns a string' {
            $result = InModuleScope TenantBaseline {
                Get-TBGradientLine -Character '-' -Length 10 -StartRGB @(255, 0, 0) -EndRGB @(0, 0, 255)
            }

            $result | Should -BeOfType [string]
        }

        It 'Contains the repeated character' {
            $result = InModuleScope TenantBaseline {
                Get-TBGradientLine -Character 'X' -Length 5 -StartRGB @(100, 100, 100) -EndRGB @(200, 200, 200)
            }

            $result | Should -Match 'X'
        }
    }
}
