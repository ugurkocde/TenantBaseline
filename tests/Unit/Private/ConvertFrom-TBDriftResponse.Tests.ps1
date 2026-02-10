#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'ConvertFrom-TBDriftResponse' {

    Context 'Converts hashtable response to typed object' {

        It 'Maps all properties from a hashtable' {
            $result = InModuleScope TenantBaseline {
                $response = @{
                    id                          = '4e808e99-7f60-4194-8294-02ede71effd8'
                    monitorId                   = 'b166c9cb-db29-438b-95fb-247da1dc72c3'
                    tenantId                    = '96bf81b4-2694-42bb-9204-70081135ca61'
                    resourceType                = 'microsoft.exchange.accepteddomain'
                    baselineResourceDisplayName = 'Accepted Domain'
                    firstReportedDateTime       = '2024-12-12T09:00:57.4830642Z'
                    status                      = 'active'
                    resourceInstanceIdentifier  = @{ Identity = 'contoso.onmicrosoft.com' }
                    driftedProperties           = @(
                        @{
                            propertyName = 'Ensure'
                            currentValue = 'Absent'
                            desiredValue = 'Present'
                        }
                    )
                }
                ConvertFrom-TBDriftResponse -Response $response
            }

            $result.PSObject.TypeNames[0] | Should -Be 'TenantBaseline.Drift'
            $result.Id | Should -Be '4e808e99-7f60-4194-8294-02ede71effd8'
            $result.MonitorId | Should -Be 'b166c9cb-db29-438b-95fb-247da1dc72c3'
            $result.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
            $result.ResourceType | Should -Be 'microsoft.exchange.accepteddomain'
            $result.BaselineResourceDisplayName | Should -Be 'Accepted Domain'
            $result.FirstReportedDateTime | Should -Be '2024-12-12T09:00:57.4830642Z'
            $result.Status | Should -Be 'active'
            $result.ResourceInstanceIdentifier | Should -Not -BeNullOrEmpty
            $result.DriftedProperties.Count | Should -Be 1
            $result.DriftedProperties[0].propertyName | Should -Be 'Ensure'
            $result.DriftedProperties[0].currentValue | Should -Be 'Absent'
            $result.DriftedProperties[0].desiredValue | Should -Be 'Present'
        }
    }

    Context 'Converts PSCustomObject response' {

        It 'Maps all properties from a PSCustomObject' {
            $result = InModuleScope TenantBaseline {
                $response = [PSCustomObject]@{
                    id                          = 'a3c17d62-e4b8-4f09-b6a1-8d2e5f7c9012'
                    monitorId                   = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                    tenantId                    = '96bf81b4-2694-42bb-9204-70081135ca61'
                    resourceType                = 'microsoft.entra.conditionalaccesspolicy'
                    baselineResourceDisplayName = 'Require MFA for All Users'
                    firstReportedDateTime       = '2025-01-15T14:22:31.6543210Z'
                    status                      = 'active'
                    resourceInstanceIdentifier  = [PSCustomObject]@{ Identity = 'CA-Policy-MFA-AllUsers' }
                    driftedProperties           = @(
                        [PSCustomObject]@{ propertyName = 'State'; currentValue = 'disabled'; desiredValue = 'enabled' }
                    )
                }
                ConvertFrom-TBDriftResponse -Response $response
            }

            $result.Id | Should -Be 'a3c17d62-e4b8-4f09-b6a1-8d2e5f7c9012'
            $result.MonitorId | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            $result.ResourceType | Should -Be 'microsoft.entra.conditionalaccesspolicy'
            $result.BaselineResourceDisplayName | Should -Be 'Require MFA for All Users'
            $result.Status | Should -Be 'active'
        }
    }

    Context 'Handles missing properties' {

        It 'Returns null or empty for properties not present in response' {
            $result = InModuleScope TenantBaseline {
                $response = @{
                    id = 'drift-minimal'
                }
                ConvertFrom-TBDriftResponse -Response $response
            }

            $result.Id | Should -Be 'drift-minimal'
            $result.MonitorId | Should -BeNullOrEmpty
            $result.TenantId | Should -BeNullOrEmpty
            $result.ResourceType | Should -BeNullOrEmpty
            $result.BaselineResourceDisplayName | Should -BeNullOrEmpty
            $result.FirstReportedDateTime | Should -BeNullOrEmpty
            $result.Status | Should -BeNullOrEmpty
            $result.ResourceInstanceIdentifier | Should -BeNullOrEmpty
            $result.DriftedProperties | Should -HaveCount 0
        }
    }

    Context 'Preserves RawResponse' {

        It 'Stores the original response in RawResponse' {
            $result = InModuleScope TenantBaseline {
                $response = @{
                    id     = 'drift-raw'
                    status = 'fixed'
                }
                ConvertFrom-TBDriftResponse -Response $response
            }

            $result.RawResponse | Should -Not -BeNullOrEmpty
            $result.RawResponse['id'] | Should -Be 'drift-raw'
        }
    }

    Context 'Works with fixture data' {

        It 'Correctly converts the DriftSingle fixture' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'DriftSingle.json') -Raw | ConvertFrom-Json

            $result = InModuleScope TenantBaseline -Parameters @{ resp = $fixtureData } {
                param($resp)
                ConvertFrom-TBDriftResponse -Response $resp
            }

            $result.Id | Should -Be '4e808e99-7f60-4194-8294-02ede71effd8'
            $result.MonitorId | Should -Be 'b166c9cb-db29-438b-95fb-247da1dc72c3'
            $result.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
            $result.ResourceType | Should -Be 'microsoft.exchange.accepteddomain'
            $result.BaselineResourceDisplayName | Should -Be 'Accepted Domain'
            $result.Status | Should -Be 'active'
            $result.DriftedProperties | Should -HaveCount 1
        }
    }
}
