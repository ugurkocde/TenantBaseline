# Migration Guide (v1.0.0)

## Breaking change: PowerShell 7.2+

TenantBaseline now requires PowerShell 7.2 or later.

### Verify your runtime

```powershell
$PSVersionTable.PSVersion
```

### Install PowerShell 7.2+

- Windows/macOS/Linux: https://learn.microsoft.com/powershell/scripting/install/installing-powershell

## Resource type canonicalization

Monitor resources now use canonical UTCM resource names (for example `microsoft.entra.conditionalaccesspolicy`).
Legacy aliases such as `microsoft.graph.conditionalAccessPolicy` are auto-migrated with warnings.

## Permission setup changes

Use permission planning before granting:

```powershell
Get-TBPermissionPlan -Workload MultiWorkload
Grant-TBServicePrincipalPermission -Workload MultiWorkload -PlanOnly
```

Grant cmdlets now return manual remediation steps for workloads that require provider-specific configuration.

## Authentication scope profiles

`Connect-TBTenant` now supports scenario-based scopes:

- `ReadOnly`: `ConfigurationMonitoring.Read.All`
- `Manage` (default): `ConfigurationMonitoring.ReadWrite.All`
- `Setup`: `ConfigurationMonitoring.ReadWrite.All` + `Application.ReadWrite.All`

If you run setup commands (`Install-TBServicePrincipal` / `Grant-TBServicePrincipalPermission`), reconnect with:

```powershell
Connect-TBTenant -Scenario Setup
```
