#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'UTCM catalog contract' {

    It 'Loads canonical catalog with expected shape' {
        $catalog = InModuleScope TenantBaseline { Get-TBUTCMCatalog -ForceReload }

        $catalog.ResourceCount | Should -BeGreaterThan 200
        @($catalog.Resources).Count | Should -Be $catalog.ResourceCount
        $catalog.Source | Should -BeLike 'https://*'
    }

    It 'Contains key canonical resource types' {
        $catalog = InModuleScope TenantBaseline { Get-TBUTCMCatalog }
        $names = @($catalog.Resources | ForEach-Object { $_.Name })

        $names | Should -Contain 'microsoft.entra.conditionalaccesspolicy'
        $names | Should -Contain 'microsoft.exchange.antiphishpolicy'
        $names | Should -Contain 'microsoft.intune.devicecompliancepolicymacos'
        $names | Should -Contain 'microsoft.teams.meetingpolicy'
        $names | Should -Contain 'microsoft.securityandcompliance.labelpolicy'
    }

    It 'Has deterministic alias mappings' {
        $catalog = InModuleScope TenantBaseline { Get-TBUTCMCatalog }

        $catalog.AliasMap.'microsoft.graph.conditionalAccessPolicy' | Should -Be 'microsoft.entra.conditionalaccesspolicy'
        $catalog.AliasMap.'microsoft.graph.authenticationMethodsPolicy' | Should -Be 'microsoft.entra.authenticationmethodpolicy'
    }
}
