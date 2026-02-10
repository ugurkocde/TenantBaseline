#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Import-TBBaseline' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Imports resources from a baseline JSON file' {

        It 'Returns resource objects from a valid baseline file' {
            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbimport-{0}.json' -f [guid]::NewGuid().ToString('N'))

            try {
                $baselineData = [PSCustomObject]@{
                    ExportedAt = '2025-01-20T10:00:00Z'
                    MonitorId  = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                    Resources  = @(
                        [PSCustomObject]@{
                            resourceType = 'microsoft.entra.conditionalaccesspolicy'
                            displayName  = 'Require MFA for All Users'
                            properties   = [PSCustomObject]@{ State = 'enabled' }
                        }
                        [PSCustomObject]@{
                            resourceType = 'microsoft.exchange.accepteddomain'
                            displayName  = 'Accepted Domain'
                            properties   = [PSCustomObject]@{ Ensure = 'Present' }
                        }
                    )
                }

                $baselineData | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempFile -Encoding utf8

                $result = @(Import-TBBaseline -Path $tempFile)

                $result.Count | Should -Be 2
                $result[0].resourceType | Should -Be 'microsoft.entra.conditionalaccesspolicy'
                $result[0].displayName | Should -Be 'Require MFA for All Users'
                $result[1].resourceType | Should -Be 'microsoft.exchange.accepteddomain'
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }

    Context 'Handles file without Resources property' {

        It 'Returns raw content when Resources property is missing' {
            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbimport-nokey-{0}.json' -f [guid]::NewGuid().ToString('N'))

            try {
                $rawData = [PSCustomObject]@{
                    displayName = 'Raw Data'
                    items       = @('one', 'two')
                }

                $rawData | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempFile -Encoding utf8

                $result = @(Import-TBBaseline -Path $tempFile)

                $result | Should -Not -BeNullOrEmpty
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }

    Context 'Validates file path' {

        It 'Throws when path does not exist' {
            { Import-TBBaseline -Path '/nonexistent/path/file.json' } | Should -Throw
        }
    }
}
