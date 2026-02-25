#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'New-TBBaselineSnapshot' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Creates a snapshot from monitor baseline' {

        It 'Extracts resource types from baseline and sends POST' {
            $baselineData = [PSCustomObject]@{
                PSTypeName  = 'TenantBaseline.Baseline'
                Id          = 'baseline-001'
                MonitorId   = 'monitor-001'
                DisplayName = 'Test Baseline'
                Description = ''
                Parameters  = @()
                Resources   = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.conditionalaccesspolicy'; displayName = 'CA'; properties = @{} }
                    [PSCustomObject]@{ resourceType = 'microsoft.exchange.accepteddomain'; displayName = 'Domain'; properties = @{} }
                )
                RawResponse = @{}
            }
            Mock -ModuleName TenantBaseline Get-TBBaseline { return $baselineData }

            $snapshotData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $snapshotData }

            $result = New-TBBaselineSnapshot -MonitorId 'monitor-001' -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'createSnapshot'
            }
        }

        It 'Uses custom display name when provided' {
            $baselineData = [PSCustomObject]@{
                PSTypeName  = 'TenantBaseline.Baseline'
                Id          = 'baseline-001'
                MonitorId   = 'monitor-001'
                DisplayName = 'Test Baseline'
                Description = ''
                Parameters  = @()
                Resources   = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.conditionalaccesspolicy'; displayName = 'CA'; properties = @{} }
                )
                RawResponse = @{}
            }
            Mock -ModuleName TenantBaseline Get-TBBaseline { return $baselineData }

            $snapshotData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $snapshotData }

            $result = New-TBBaselineSnapshot -MonitorId 'monitor-001' -DisplayName 'My Custom Snapshot' -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }

    Context 'Handles empty baseline' {

        It 'Returns nothing when baseline has no resources' {
            $baselineData = [PSCustomObject]@{
                PSTypeName  = 'TenantBaseline.Baseline'
                Id          = 'baseline-001'
                MonitorId   = 'monitor-001'
                DisplayName = 'Empty Baseline'
                Description = ''
                Parameters  = @()
                Resources   = @()
                RawResponse = @{}
            }
            Mock -ModuleName TenantBaseline Get-TBBaseline { return $baselineData }

            $result = New-TBBaselineSnapshot -MonitorId 'monitor-001' -Confirm:$false

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Supports -WhatIf' {

        It 'Does not invoke the API when -WhatIf is used' {
            $baselineData = [PSCustomObject]@{
                PSTypeName  = 'TenantBaseline.Baseline'
                Id          = 'baseline-001'
                MonitorId   = 'monitor-001'
                DisplayName = 'Test Baseline'
                Description = ''
                Parameters  = @()
                Resources   = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.conditionalaccesspolicy'; displayName = 'CA'; properties = @{} }
                )
                RawResponse = @{}
            }
            Mock -ModuleName TenantBaseline Get-TBBaseline { return $baselineData }
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return @{} }

            New-TBBaselineSnapshot -MonitorId 'monitor-001' -WhatIf

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }
}
