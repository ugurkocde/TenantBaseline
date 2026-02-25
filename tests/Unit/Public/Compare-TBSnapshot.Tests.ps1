#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Compare-TBSnapshot' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Detects property changes between snapshots' {

        It 'Returns Changed diffs when properties differ' {
            $refSnap = [PSCustomObject]@{
                Id = 'ref-001'; Status = 'succeeded'; ResourceLocation = 'https://example.com/ref'
                DisplayName = 'Ref'; Resources = @()
            }
            $diffSnap = [PSCustomObject]@{
                Id = 'diff-001'; Status = 'succeeded'; ResourceLocation = 'https://example.com/diff'
                DisplayName = 'Diff'; Resources = @()
            }
            Mock -ModuleName TenantBaseline Get-TBSnapshot {
                if ($SnapshotId -eq 'ref-001') { return $refSnap }
                return $diffSnap
            }

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'ref$') {
                    return @(
                        [PSCustomObject]@{
                            resourceType = 'microsoft.entra.conditionalaccesspolicy'
                            displayName  = 'MFA Policy'
                            properties   = [PSCustomObject]@{ State = 'enabled'; DisplayName = 'MFA' }
                        }
                    )
                }
                return @(
                    [PSCustomObject]@{
                        resourceType = 'microsoft.entra.conditionalaccesspolicy'
                        displayName  = 'MFA Policy'
                        properties   = [PSCustomObject]@{ State = 'disabled'; DisplayName = 'MFA' }
                    }
                )
            }

            $result = Compare-TBSnapshot -ReferenceSnapshotId 'ref-001' -DifferenceSnapshotId 'diff-001'

            $result | Should -Not -BeNullOrEmpty
            $changedDiff = $result | Where-Object { $_.Property -eq 'State' }
            $changedDiff | Should -Not -BeNullOrEmpty
            $changedDiff.DiffType | Should -Be 'Changed'
            $changedDiff.ReferenceValue | Should -Be 'enabled'
            $changedDiff.DifferenceValue | Should -Be 'disabled'
        }
    }

    Context 'Detects added and removed resources' {

        It 'Returns Added when resource exists only in difference' {
            $refSnap = [PSCustomObject]@{
                Id = 'ref-001'; Status = 'succeeded'; ResourceLocation = 'https://example.com/ref'
            }
            $diffSnap = [PSCustomObject]@{
                Id = 'diff-001'; Status = 'succeeded'; ResourceLocation = 'https://example.com/diff'
            }
            Mock -ModuleName TenantBaseline Get-TBSnapshot {
                if ($SnapshotId -eq 'ref-001') { return $refSnap }
                return $diffSnap
            }

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'ref$') {
                    return @()
                }
                return @(
                    [PSCustomObject]@{
                        resourceType = 'microsoft.entra.group'
                        displayName  = 'New Group'
                        properties   = [PSCustomObject]@{ DisplayName = 'New Group' }
                    }
                )
            }

            $result = Compare-TBSnapshot -ReferenceSnapshotId 'ref-001' -DifferenceSnapshotId 'diff-001'

            $result | Should -Not -BeNullOrEmpty
            $added = $result | Where-Object { $_.DiffType -eq 'Added' }
            $added | Should -Not -BeNullOrEmpty
        }

        It 'Returns Removed when resource exists only in reference' {
            $refSnap = [PSCustomObject]@{
                Id = 'ref-001'; Status = 'succeeded'; ResourceLocation = 'https://example.com/ref'
            }
            $diffSnap = [PSCustomObject]@{
                Id = 'diff-001'; Status = 'succeeded'; ResourceLocation = 'https://example.com/diff'
            }
            Mock -ModuleName TenantBaseline Get-TBSnapshot {
                if ($SnapshotId -eq 'ref-001') { return $refSnap }
                return $diffSnap
            }

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'ref$') {
                    return @(
                        [PSCustomObject]@{
                            resourceType = 'microsoft.entra.group'
                            displayName  = 'Old Group'
                            properties   = [PSCustomObject]@{ DisplayName = 'Old Group' }
                        }
                    )
                }
                return @()
            }

            $result = Compare-TBSnapshot -ReferenceSnapshotId 'ref-001' -DifferenceSnapshotId 'diff-001'

            $result | Should -Not -BeNullOrEmpty
            $removed = $result | Where-Object { $_.DiffType -eq 'Removed' }
            $removed | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Handles non-succeeded snapshots' {

        It 'Returns nothing for running snapshots' {
            $refSnap = [PSCustomObject]@{
                Id = 'ref-001'; Status = 'running'; ResourceLocation = $null
            }
            Mock -ModuleName TenantBaseline Get-TBSnapshot { return $refSnap }

            $result = Compare-TBSnapshot -ReferenceSnapshotId 'ref-001' -DifferenceSnapshotId 'diff-001'

            $result | Should -BeNullOrEmpty
        }
    }
}
