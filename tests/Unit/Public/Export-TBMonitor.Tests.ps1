#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Export-TBMonitor' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Exports a monitor to JSON' {

        It 'Fetches monitor and baseline then writes file' {
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorSingle.json') -Raw | ConvertFrom-Json
            $mockMonitor = [PSCustomObject]@{
                PSTypeName  = 'TenantBaseline.Monitor'
                Id          = $monitorData.id
                DisplayName = $monitorData.displayName
                Description = 'Test monitor'
                Status      = $monitorData.status
            }
            Mock -ModuleName TenantBaseline Get-TBMonitor { return $mockMonitor }

            $mockBaseline = [PSCustomObject]@{
                PSTypeName  = 'TenantBaseline.Baseline'
                Id          = 'baseline-001'
                MonitorId   = $monitorData.id
                DisplayName = 'Test Baseline'
                Description = ''
                Parameters  = @()
                Resources   = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.conditionalaccesspolicy'; displayName = 'CA'; properties = @{} }
                )
                RawResponse = @{}
            }
            Mock -ModuleName TenantBaseline Get-TBBaseline { return $mockBaseline }

            $outputFile = Join-Path $TestDrive 'export-test.json'
            $result = Export-TBMonitor -MonitorId $monitorData.id -OutputPath $outputFile -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.OutputPath | Should -BeLike '*export-test.json'
            Test-Path $result.OutputPath | Should -BeTrue

            $content = Get-Content $result.OutputPath -Raw | ConvertFrom-Json
            $content.MonitorId | Should -Be $monitorData.id
            $content.DisplayName | Should -Be $monitorData.displayName
            $content.Baseline | Should -Not -BeNullOrEmpty
        }
    }
}
