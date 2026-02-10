#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'New-TBDashboard' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Generates a dashboard HTML file' {

        It 'Creates an HTML file with embedded JSON data' {
            $driftData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            $resultData = Get-Content -Path (Join-Path $fixturesPath 'MonitorResultList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationDrifts') {
                    return $driftData
                }
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                if ($Uri -match 'configurationMonitoringResults') {
                    return $resultData
                }
                return [PSCustomObject]@{ value = @() }
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdash-{0}.html' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDashboard -OutputPath $tempFile -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                $result.MonitorCount | Should -Be 2
                $result.DriftCount | Should -Be 3
                $result.SnapshotCount | Should -Be 0
                Test-Path -Path $tempFile | Should -BeTrue

                $htmlContent = Get-Content -Path $tempFile -Raw
                $htmlContent | Should -Match 'TenantBaseline Dashboard'
                $htmlContent | Should -Match 'tb-data'
                $htmlContent | Should -Match 'application/json'
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }

        It 'Includes snapshot data when -IncludeSnapshots is specified' {
            $driftData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            $resultData = Get-Content -Path (Join-Path $fixturesPath 'MonitorResultList.json') -Raw | ConvertFrom-Json
            $snapshotData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationDrifts') {
                    return $driftData
                }
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                if ($Uri -match 'configurationMonitoringResults') {
                    return $resultData
                }
                if ($Uri -match 'configurationSnapshotJobs') {
                    return $snapshotData
                }
                return [PSCustomObject]@{ value = @() }
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdash-snap-{0}.html' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDashboard -OutputPath $tempFile -IncludeSnapshots -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                $result.SnapshotCount | Should -Be 2
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }

    Context 'Contains dashboard elements' {

        It 'Includes tab navigation and filter elements' {
            $driftData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            $resultData = Get-Content -Path (Join-Path $fixturesPath 'MonitorResultList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationDrifts') {
                    return $driftData
                }
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                if ($Uri -match 'configurationMonitoringResults') {
                    return $resultData
                }
                return [PSCustomObject]@{ value = @() }
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdash-tabs-{0}.html' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDashboard -OutputPath $tempFile -Confirm:$false
                $htmlContent = Get-Content -Path $tempFile -Raw

                $htmlContent | Should -Match 'panel-overview'
                $htmlContent | Should -Match 'panel-timeline'
                $htmlContent | Should -Match 'panel-monitors'
                $htmlContent | Should -Match 'panel-snapshots'
                $htmlContent | Should -Match 'filter-status'
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }

    Context 'Handles empty data' {

        It 'Generates dashboard with no drifts' {
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                return [PSCustomObject]@{ value = @() }
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdash-empty-{0}.html' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDashboard -OutputPath $tempFile -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                $result.DriftCount | Should -Be 0
                Test-Path -Path $tempFile | Should -BeTrue
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }

    Context 'Supports -WhatIf' {

        It 'Does not create a file when -WhatIf is used' {
            $driftData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationDrifts') {
                    return $driftData
                }
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                return [PSCustomObject]@{ value = @() }
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdash-whatif-{0}.html' -f [guid]::NewGuid().ToString('N'))

            New-TBDashboard -OutputPath $tempFile -WhatIf

            Test-Path -Path $tempFile | Should -BeFalse
        }
    }

    Context 'Default output path' {

        It 'Generates a default filename when no OutputPath is given' {
            $driftData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationDrifts') {
                    return $driftData
                }
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                return [PSCustomObject]@{ value = @() }
            }

            try {
                $result = New-TBDashboard -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                $result.OutputPath | Should -Match 'TBDashboard-'
                $result.OutputPath | Should -Match '\.html$'
            }
            finally {
                if ($result -and $result.OutputPath -and (Test-Path -Path $result.OutputPath)) {
                    Remove-Item -Path $result.OutputPath -Force
                }
            }
        }
    }

    Context 'MonitorId filter' {

        It 'Passes MonitorId to drift retrieval' {
            $driftData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationDrifts') {
                    return $driftData
                }
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                return [PSCustomObject]@{ value = @() }
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdash-monid-{0}.html' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDashboard -OutputPath $tempFile -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                Test-Path -Path $tempFile | Should -BeTrue
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }
}
