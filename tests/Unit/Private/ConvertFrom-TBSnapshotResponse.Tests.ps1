#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'ConvertFrom-TBSnapshotResponse' {

    Context 'Converts hashtable response to typed object' {

        It 'Maps all properties from a hashtable' {
            $result = InModuleScope TenantBaseline {
                $response = @{
                    id                = 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
                    displayName       = 'Weekly Baseline Snapshot'
                    description       = 'Scheduled weekly snapshot of tenant configuration'
                    status            = 'succeeded'
                    tenantId          = '96bf81b4-2694-42bb-9204-70081135ca61'
                    createdDateTime   = '2025-01-20T02:00:00.0000000Z'
                    completedDateTime = '2025-01-20T02:15:43.7654321Z'
                    createdBy         = @{ user = @{ id = '823da47e-fc25-48d8-8b5a-6186c760f0df'; displayName = 'Admin User' } }
                    resources         = @('microsoft.exchange.accepteddomain', 'microsoft.entra.conditionalaccesspolicy', 'microsoft.exchange.transportrule')
                    resourceLocation  = 'https://graph.microsoft.com/beta/admin/configurationManagement/configurationSnapshots/e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34/content'
                    errorDetails      = @()
                }
                ConvertFrom-TBSnapshotResponse -Response $response
            }

            $result.PSObject.TypeNames[0] | Should -Be 'TenantBaseline.Snapshot'
            $result.Id | Should -Be 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
            $result.DisplayName | Should -Be 'Weekly Baseline Snapshot'
            $result.Description | Should -Be 'Scheduled weekly snapshot of tenant configuration'
            $result.Status | Should -Be 'succeeded'
            $result.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
            $result.CreatedDateTime | Should -Be '2025-01-20T02:00:00.0000000Z'
            $result.CompletedDateTime | Should -Be '2025-01-20T02:15:43.7654321Z'
            $result.CreatedBy | Should -Not -BeNullOrEmpty
            $result.Resources | Should -HaveCount 3
            $result.Resources | Should -Contain 'microsoft.exchange.accepteddomain'
            $result.ResourceLocation | Should -Match 'configurationSnapshots'
            $result.ErrorDetails | Should -HaveCount 0
        }
    }

    Context 'Converts PSCustomObject response' {

        It 'Maps properties from a PSCustomObject' {
            $result = InModuleScope TenantBaseline {
                $response = [PSCustomObject]@{
                    id          = 'f9b3d5e7-0a21-4c4f-ae6b-2d8f3f9c1b45'
                    displayName = 'On-Demand Snapshot'
                    status      = 'running'
                    tenantId    = '96bf81b4-2694-42bb-9204-70081135ca61'
                }
                ConvertFrom-TBSnapshotResponse -Response $response
            }

            $result.Id | Should -Be 'f9b3d5e7-0a21-4c4f-ae6b-2d8f3f9c1b45'
            $result.DisplayName | Should -Be 'On-Demand Snapshot'
            $result.Status | Should -Be 'running'
        }
    }

    Context 'Handles missing properties' {

        It 'Returns null or empty for properties not present in response' {
            $result = InModuleScope TenantBaseline {
                $response = @{ id = 'snap-minimal' }
                ConvertFrom-TBSnapshotResponse -Response $response
            }

            $result.Id | Should -Be 'snap-minimal'
            $result.DisplayName | Should -BeNullOrEmpty
            $result.Description | Should -BeNullOrEmpty
            $result.Status | Should -BeNullOrEmpty
            $result.TenantId | Should -BeNullOrEmpty
            $result.CreatedDateTime | Should -BeNullOrEmpty
            $result.CompletedDateTime | Should -BeNullOrEmpty
            $result.CreatedBy | Should -BeNullOrEmpty
            $result.Resources | Should -HaveCount 0
            $result.ResourceLocation | Should -BeNullOrEmpty
            $result.ErrorDetails | Should -HaveCount 0
        }
    }

    Context 'Preserves RawResponse' {

        It 'Stores the original response in RawResponse' {
            $result = InModuleScope TenantBaseline {
                $response = @{ id = 'snap-raw'; status = 'succeeded' }
                ConvertFrom-TBSnapshotResponse -Response $response
            }

            $result.RawResponse | Should -Not -BeNullOrEmpty
            $result.RawResponse['id'] | Should -Be 'snap-raw'
        }
    }

    Context 'Works with fixture data' {

        It 'Correctly converts the SnapshotSingle fixture' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json

            $result = InModuleScope TenantBaseline -Parameters @{ resp = $fixtureData } {
                param($resp)
                ConvertFrom-TBSnapshotResponse -Response $resp
            }

            $result.Id | Should -Be 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
            $result.DisplayName | Should -Be 'Weekly Baseline Snapshot'
            $result.Status | Should -Be 'succeeded'
            $result.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
            $result.CreatedDateTime | Should -Not -BeNullOrEmpty
            $result.CompletedDateTime | Should -Not -BeNullOrEmpty
            $result.Resources | Should -HaveCount 3
        }
    }
}
