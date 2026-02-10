#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-TBResourceTypeRegistry' {

    Context 'Returns valid registry structure' {

        It 'Returns a hashtable' {
            $result = InModuleScope TenantBaseline {
                Get-TBResourceTypeRegistry
            }

            $result | Should -BeOfType [hashtable]
        }

        It 'Contains expected workloads' {
            $result = InModuleScope TenantBaseline {
                Get-TBResourceTypeRegistry
            }

            $result.ContainsKey('Exchange Online') | Should -BeTrue
            $result.ContainsKey('Entra ID') | Should -BeTrue
            $result.ContainsKey('Teams') | Should -BeTrue
            $result.ContainsKey('Intune') | Should -BeTrue
        }

        It 'Each workload has WorkloadId and ResourceTypes' {
            $result = InModuleScope TenantBaseline {
                Get-TBResourceTypeRegistry
            }

            foreach ($key in $result.Keys) {
                $result[$key].WorkloadId | Should -Not -BeNullOrEmpty
                $result[$key].ResourceTypes | Should -Not -BeNullOrEmpty
                $result[$key].ResourceTypes.Count | Should -BeGreaterThan 0
            }
        }

        It 'Each resource type has Name and DisplayName' {
            $result = InModuleScope TenantBaseline {
                Get-TBResourceTypeRegistry
            }

            foreach ($key in $result.Keys) {
                foreach ($rt in $result[$key].ResourceTypes) {
                    $rt.Name | Should -Not -BeNullOrEmpty
                    $rt.DisplayName | Should -Not -BeNullOrEmpty
                }
            }
        }

        It 'Resource type names follow microsoft.<workload>.<resource> format' {
            $result = InModuleScope TenantBaseline {
                Get-TBResourceTypeRegistry
            }

            foreach ($key in $result.Keys) {
                foreach ($rt in $result[$key].ResourceTypes) {
                    $rt.Name | Should -Match '^microsoft\.\w+\.\w+'
                }
            }
        }
    }

    Context 'Exchange Online workload' {

        It 'Has correct WorkloadId' {
            $result = InModuleScope TenantBaseline {
                Get-TBResourceTypeRegistry
            }

            $result['Exchange Online'].WorkloadId | Should -Be 'ExchangeOnline'
        }

        It 'Contains known Exchange resource types' {
            $result = InModuleScope TenantBaseline {
                Get-TBResourceTypeRegistry
            }

            $names = $result['Exchange Online'].ResourceTypes | ForEach-Object { $_.Name }
            $names | Should -Contain 'microsoft.exchange.accepteddomain'
            $names | Should -Contain 'microsoft.exchange.antiphishpolicy'
            $names | Should -Contain 'microsoft.exchange.dkimsigningconfig'
        }
    }

    Context 'Entra ID workload' {

        It 'Has correct WorkloadId' {
            $result = InModuleScope TenantBaseline {
                Get-TBResourceTypeRegistry
            }

            $result['Entra ID'].WorkloadId | Should -Be 'EntraID'
        }

        It 'Contains known Entra resource types' {
            $result = InModuleScope TenantBaseline {
                Get-TBResourceTypeRegistry
            }

            $names = $result['Entra ID'].ResourceTypes | ForEach-Object { $_.Name }
            $names | Should -Contain 'microsoft.entra.conditionalaccesspolicy'
            $names | Should -Contain 'microsoft.entra.authorizationpolicy'
        }
    }
}
