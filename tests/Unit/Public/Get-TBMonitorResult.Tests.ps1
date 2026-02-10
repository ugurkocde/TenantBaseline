#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Get-TBMonitorResult' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Lists all monitor results' {

        It 'Returns all results from the fixture' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorResultList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = @(Get-TBMonitorResult)

            $result.Count | Should -Be 2
            $result[0].Id | Should -Be '7a8b9c0d-1234-5678-9abc-def012345678'
            $result[0].MonitorId | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            $result[0].RunStatus | Should -Be 'successful'
            $result[0].DriftsCount | Should -Be 2
            $result[0].TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
            $result[0].RunInitiationDateTime | Should -Not -BeNullOrEmpty
            $result[0].RunCompletionDateTime | Should -Not -BeNullOrEmpty
        }

        It 'Returns failed results with error details' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorResultList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = @(Get-TBMonitorResult)

            $result[1].RunStatus | Should -Be 'failed'
            $result[1].DriftsCount | Should -Be 0
            $result[1].ErrorDetails | Should -HaveCount 1
            $result[1].ErrorDetails[0].errorCode | Should -Be 'Authorization_RequestDenied'
        }
    }

    Context 'Returns typed monitor result objects' {

        It 'Returns objects with TenantBaseline.MonitorResult type name' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorResultList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = @(Get-TBMonitorResult)

            $result[0].PSObject.TypeNames[0] | Should -Be 'TenantBaseline.MonitorResult'
            $result[0].PSObject.Properties['Id'] | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties['MonitorId'] | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties['RunStatus'] | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties['DriftsCount'] | Should -Not -BeNullOrEmpty
            $result[0].PSObject.Properties['RawResponse'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Filters by MonitorId' {

        It 'Includes filter parameter in the URI when MonitorId is specified' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorResultList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $null = Get-TBMonitorResult -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Uri -match 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            }
        }
    }

    Context 'Handles empty response' {

        It 'Returns nothing when API returns empty value array' {
            $emptyData = Get-Content -Path (Join-Path $fixturesPath 'EmptyResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $emptyData }

            $result = @(Get-TBMonitorResult)

            $result.Count | Should -Be 0
        }
    }
}
