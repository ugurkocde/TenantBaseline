#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-TBGraphBaseUri' {

    Context 'Returns correct URI for each environment' {

        It 'Returns Global URI when environment is Global' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{ Environment = 'Global' }
            }

            $result = InModuleScope TenantBaseline { Get-TBGraphBaseUri }
            $result | Should -Be 'https://graph.microsoft.com'
        }

        It 'Returns USGov URI when environment is USGov' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{ Environment = 'USGov' }
            }

            $result = InModuleScope TenantBaseline { Get-TBGraphBaseUri }
            $result | Should -Be 'https://graph.microsoft.us'
        }

        It 'Returns USGovDoD URI when environment is USGovDoD' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{ Environment = 'USGovDoD' }
            }

            $result = InModuleScope TenantBaseline { Get-TBGraphBaseUri }
            $result | Should -Be 'https://dod-graph.microsoft.us'
        }

        It 'Returns China URI when environment is China' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{ Environment = 'China' }
            }

            $result = InModuleScope TenantBaseline { Get-TBGraphBaseUri }
            $result | Should -Be 'https://microsoftgraph.chinacloudapi.cn'
        }
    }

    Context 'Falls back to Global when environment is missing' {

        It 'Returns Global URI when context has no Environment property' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{ TenantId = 'some-id' }
            }

            $result = InModuleScope TenantBaseline { Get-TBGraphBaseUri }
            $result | Should -Be 'https://graph.microsoft.com'
        }

        It 'Returns Global URI when context is null' {
            Mock -ModuleName TenantBaseline Get-MgContext { return $null }

            $result = InModuleScope TenantBaseline { Get-TBGraphBaseUri }
            $result | Should -Be 'https://graph.microsoft.com'
        }
    }
}
