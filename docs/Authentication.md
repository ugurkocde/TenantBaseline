# Authentication

TenantBaseline uses interactive/delegated authentication via Microsoft's `Connect-MgGraph` cmdlet. No custom app registration is needed.

## How It Works

When you run `Connect-TBTenant`, the module:

1. Calls `Connect-MgGraph` with the required scopes
2. Opens a browser window for interactive authentication
3. Stores the session context for subsequent API calls

## Required Scopes

`Connect-TBTenant` supports scenario-based scope profiles:

| Scenario | Scopes | Purpose |
|----------|--------|---------|
| `ReadOnly` | `ConfigurationMonitoring.Read.All` | Read monitors, drifts, and snapshots |
| `Manage` | `ConfigurationMonitoring.ReadWrite.All` | Create/update monitors and snapshots |
| `Setup` | `ConfigurationMonitoring.ReadWrite.All`, `Application.ReadWrite.All` | Provision/grant UTCM service principal permissions |

## Connection Examples

```powershell
# Default connection profile (Manage)
Connect-TBTenant

# Read-only session
Connect-TBTenant -Scenario ReadOnly

# Setup session (required for Install/Grant service principal commands)
Connect-TBTenant -Scenario Setup

# Connect to a specific tenant
Connect-TBTenant -TenantId 'contoso.onmicrosoft.com'

# Add extra scopes if needed
Connect-TBTenant -Scopes @('DeviceManagementConfiguration.Read.All')
```

## UTCM Service Principal

The UTCM service principal (AppId: `03b07b79-c5bc-4b5e-9bfa-13acf4a99998`) is a Microsoft first-party application. It must be provisioned once per tenant for monitors to execute.

```powershell
# Check if it exists
Test-TBServicePrincipal

# Provision it
Install-TBServicePrincipal

# Grant permissions for workloads
Grant-TBServicePrincipalPermission -Workload MultiWorkload

# Preview plan (no changes)
Get-TBPermissionPlan -Workload MultiWorkload
```

## Required Roles

| Operation | Minimum Role |
|-----------|-------------|
| Connect and read | Security Reader |
| Create/update monitors | Security Administrator |
| Install service principal | Global Administrator or Application Administrator |
| Grant permissions | Global Administrator or Privileged Role Administrator |

## Session Management

```powershell
# Check connection status
Get-TBConnectionStatus

# Disconnect
Disconnect-TBTenant
```
