#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Read-TBUserInput' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-Host {}
    }

    Context 'Basic input' {

        It 'Returns user input value' {
            Mock -ModuleName TenantBaseline Read-Host { return 'hello' }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Enter value'
            }

            $result | Should -Be 'hello'
        }

        It 'Returns empty string for optional empty input' {
            Mock -ModuleName TenantBaseline Read-Host { return '' }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Enter value'
            }

            $result | Should -Be ''
        }
    }

    Context 'Mandatory input' {

        It 'Retries on empty then accepts valid input' {
            $script:callCount = 0
            Mock -ModuleName TenantBaseline Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { return '' }
                return 'valid'
            }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Required' -Mandatory
            }

            $result | Should -Be 'valid'
        }
    }

    Context 'Length validation' {

        It 'Rejects input shorter than MinLength then accepts valid' {
            $script:callCount = 0
            Mock -ModuleName TenantBaseline Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { return 'ab' }
                return 'abcdef'
            }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Name' -Mandatory -MinLength 5
            }

            $result | Should -Be 'abcdef'
        }

        It 'Rejects input longer than MaxLength then accepts valid' {
            $script:callCount = 0
            Mock -ModuleName TenantBaseline Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { return 'this is way too long for the field' }
                return 'short'
            }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Name' -Mandatory -MaxLength 10
            }

            $result | Should -Be 'short'
        }
    }

    Context 'Pattern validation' {

        It 'Rejects input not matching pattern then accepts valid' {
            $script:callCount = 0
            Mock -ModuleName TenantBaseline Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) { return 'invalid!@#' }
                return 'Valid Name 1'
            }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Name' -Mandatory -Pattern '^[a-zA-Z0-9 ]+$' -PatternMessage 'Alphanumeric only'
            }

            $result | Should -Be 'Valid Name 1'
        }
    }

    Context 'Confirm mode' {

        It 'Returns true for Y input' {
            Mock -ModuleName TenantBaseline Read-Host { return 'Y' }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Continue?' -Confirm
            }

            $result | Should -BeTrue
        }

        It 'Returns false for N input' {
            Mock -ModuleName TenantBaseline Read-Host { return 'N' }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Continue?' -Confirm
            }

            $result | Should -BeFalse
        }

        It 'Returns true for lowercase y' {
            Mock -ModuleName TenantBaseline Read-Host { return 'y' }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Continue?' -Confirm
            }

            $result | Should -BeTrue
        }

        It 'Uses default value when input is empty' {
            Mock -ModuleName TenantBaseline Read-Host { return '' }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Continue?' -Confirm -Default 'Y'
            }

            $result | Should -BeTrue
        }
    }

    Context 'Default value' {

        It 'Returns default when input is empty' {
            Mock -ModuleName TenantBaseline Read-Host { return '' }

            $result = InModuleScope TenantBaseline {
                Read-TBUserInput -Prompt 'Value' -Default 'fallback'
            }

            $result | Should -Be 'fallback'
        }
    }
}
