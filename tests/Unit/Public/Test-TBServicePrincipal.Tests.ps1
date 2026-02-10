#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Test-TBServicePrincipal' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection {}
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Service principal exists' {

        It 'Returns $true when the SP is found' {
            $spListData = Get-Content -Path (Join-Path $fixturesPath 'ServicePrincipalList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $spListData }

            $result = Test-TBServicePrincipal

            $result | Should -BeTrue
        }
    }

    Context 'Service principal does not exist' {

        It 'Returns $false when the SP is not found' {
            $emptyResponse = Get-Content -Path (Join-Path $fixturesPath 'EmptyResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $emptyResponse }

            $result = Test-TBServicePrincipal

            $result | Should -BeFalse
        }
    }

    Context 'Handles API errors gracefully' {

        It 'Returns $false when the API call throws' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { throw 'API error' }

            $result = Test-TBServicePrincipal

            $result | Should -BeFalse
        }
    }
}
