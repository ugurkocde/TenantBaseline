#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Get-TBDrift' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Lists all drifts' {

        It 'Returns all drifts from the fixture' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = @(Get-TBDrift)

            $result.Count | Should -Be 3
            $result[0].Id | Should -Be '4e808e99-7f60-4194-8294-02ede71effd8'
            $result[0].ResourceType | Should -Be 'microsoft.exchange.accepteddomain'
            $result[0].BaselineResourceDisplayName | Should -Be 'Accepted Domain'
            $result[0].Status | Should -Be 'active'
            $result[0].DriftedProperties | Should -HaveCount 1

            $result[1].Id | Should -Be 'a3c17d62-e4b8-4f09-b6a1-8d2e5f7c9012'
            $result[1].ResourceType | Should -Be 'microsoft.entra.conditionalaccesspolicy'
            $result[1].DriftedProperties | Should -HaveCount 2

            $result[2].Id | Should -Be 'c8f94b21-3a6e-4d70-9e85-1b4c7f0a2d63'
            $result[2].Status | Should -Be 'fixed'
        }
    }

    Context 'Gets a single drift by ID' {

        It 'Returns a single drift when DriftId is specified' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'DriftSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBDrift -DriftId '4e808e99-7f60-4194-8294-02ede71effd8'

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be '4e808e99-7f60-4194-8294-02ede71effd8'
            $result.MonitorId | Should -Be 'b166c9cb-db29-438b-95fb-247da1dc72c3'
            $result.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
            $result.ResourceType | Should -Be 'microsoft.exchange.accepteddomain'
            $result.BaselineResourceDisplayName | Should -Be 'Accepted Domain'
            $result.FirstReportedDateTime | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be 'active'
        }
    }

    Context 'Returns typed drift objects' {

        It 'Returns objects with TenantBaseline.Drift type name' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'DriftSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBDrift -DriftId '4e808e99-7f60-4194-8294-02ede71effd8'

            $result.PSObject.TypeNames[0] | Should -Be 'TenantBaseline.Drift'
            $result.PSObject.Properties['ResourceInstanceIdentifier'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['DriftedProperties'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Filters by MonitorId' {

        It 'Includes MonitorId filter in the URI' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $null = @(Get-TBDrift -MonitorId 'b166c9cb-db29-438b-95fb-247da1dc72c3')

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Uri -match 'b166c9cb-db29-438b-95fb-247da1dc72c3'
            }
        }
    }

    Context 'Handles empty response' {

        It 'Returns nothing when API returns empty value array' {
            $emptyData = Get-Content -Path (Join-Path $fixturesPath 'EmptyResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $emptyData }

            $result = @(Get-TBDrift)

            $result.Count | Should -Be 0
        }
    }
}
