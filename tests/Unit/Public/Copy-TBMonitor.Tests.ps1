#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Copy-TBMonitor' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Clones a monitor' {

        It 'Reads source monitor and baseline then creates a new monitor' {
            $mockMonitor = [PSCustomObject]@{
                PSTypeName  = 'TenantBaseline.Monitor'
                Id          = 'source-monitor-001'
                DisplayName = 'Source Monitor'
                Description = 'Original description'
                Status      = 'active'
            }
            Mock -ModuleName TenantBaseline Get-TBMonitor {
                param($MonitorId)
                return $mockMonitor
            }

            $mockBaseline = [PSCustomObject]@{
                PSTypeName  = 'TenantBaseline.Baseline'
                Id          = 'baseline-001'
                MonitorId   = 'source-monitor-001'
                DisplayName = 'Source Baseline'
                Description = ''
                Parameters  = @()
                Resources   = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.conditionalaccesspolicy'; displayName = 'CA'; properties = @{ State = 'enabled' } }
                )
                RawResponse = @{}
            }
            Mock -ModuleName TenantBaseline Get-TBBaseline { return $mockBaseline }

            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Copy-TBMonitor -MonitorId 'source-monitor-001' -DisplayName 'Cloned Monitor' -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Get-TBBaseline -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }

    Context 'Supports -WhatIf' {

        It 'Does not create a monitor when -WhatIf is used' {
            $mockMonitor = [PSCustomObject]@{
                Id = 'source-001'; DisplayName = 'Source'; Description = ''; Status = 'active'
            }
            Mock -ModuleName TenantBaseline Get-TBMonitor { return $mockMonitor }

            $mockBaseline = [PSCustomObject]@{
                Resources = @(); Parameters = @(); DisplayName = 'BL'; Description = ''
            }
            Mock -ModuleName TenantBaseline Get-TBBaseline { return $mockBaseline }
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return @{} }

            Copy-TBMonitor -MonitorId 'source-001' -DisplayName 'WhatIf Clone' -WhatIf

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }
}
