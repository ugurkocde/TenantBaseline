#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-TBQuotaStatus' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Returns quota usage and limits' {

        It 'Calculates monitor count and resource-day usage' {
            $mockMonitors = @(
                [PSCustomObject]@{ Id = 'mon-1'; DisplayName = 'Monitor 1'; Status = 'active' }
                [PSCustomObject]@{ Id = 'mon-2'; DisplayName = 'Monitor 2'; Status = 'active' }
            )
            Mock -ModuleName TenantBaseline Get-TBMonitor { return $mockMonitors }

            $baseline1 = [PSCustomObject]@{
                Resources = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.conditionalaccesspolicy' }
                    [PSCustomObject]@{ resourceType = 'microsoft.exchange.accepteddomain' }
                )
            }
            $baseline2 = [PSCustomObject]@{
                Resources = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.group' }
                )
            }
            Mock -ModuleName TenantBaseline Get-TBBaseline {
                if ($MonitorId -eq 'mon-1') { return $baseline1 }
                return $baseline2
            }

            Mock -ModuleName TenantBaseline Get-TBSnapshot { return @() }

            $result = Get-TBQuotaStatus

            $result | Should -Not -BeNullOrEmpty
            $result.MonitorCount | Should -Be 2
            $result.MonitorLimit | Should -Be 30
            $result.TotalBaselineResources | Should -Be 3
            $result.MonitoredResourcesPerDay | Should -Be 12
            $result.ResourceDayLimit | Should -Be 800
            $result.SnapshotJobCount | Should -Be 0
            $result.SnapshotJobLimit | Should -Be 12
        }

        It 'Counts snapshot jobs' {
            Mock -ModuleName TenantBaseline Get-TBMonitor { return @() }
            Mock -ModuleName TenantBaseline Get-TBSnapshot {
                return @(
                    [PSCustomObject]@{ Id = 'snap-1' }
                    [PSCustomObject]@{ Id = 'snap-2' }
                    [PSCustomObject]@{ Id = 'snap-3' }
                )
            }

            $result = Get-TBQuotaStatus

            $result.MonitorCount | Should -Be 0
            $result.SnapshotJobCount | Should -Be 3
        }
    }
}
