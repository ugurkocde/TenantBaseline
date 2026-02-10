#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Invoke-TBGraphPagedRequest' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    It 'Returns all pages when @odata.nextLink is present' {
        $script:count = 0
        Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
            $script:count++
            if ($script:count -eq 1) {
                return [PSCustomObject]@{
                    value = @([PSCustomObject]@{ id = '1' })
                    '@odata.nextLink' = 'https://graph.microsoft.com/next-page'
                }
            }

            return [PSCustomObject]@{
                value = @([PSCustomObject]@{ id = '2' })
            }
        }

        $result = InModuleScope TenantBaseline { Invoke-TBGraphPagedRequest -Uri 'https://graph.microsoft.com/first-page' }

        @($result).Count | Should -Be 2
        $result[0].id | Should -Be '1'
        $result[1].id | Should -Be '2'
    }
}
