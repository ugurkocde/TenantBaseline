# Authentication

TenantBaseline supports both delegated interactive sign-in and unattended automation through Microsoft's `Connect-MgGraph` cmdlet.

## Delegated Authentication

Delegated auth is the default mode for local admin usage. When you run `Connect-TBTenant` without an unattended parameter set, the module:

1. Calls `Connect-MgGraph` with the required scopes
2. Opens a browser window or device code prompt for authentication
3. Stores the session context for subsequent API calls

### Delegated scope profiles

| Scenario | Scopes | Purpose |
|----------|--------|---------|
| `ReadOnly` | `ConfigurationMonitoring.Read.All` | Read monitors, drifts, and snapshots |
| `Manage` | `ConfigurationMonitoring.ReadWrite.All` | Create/update monitors and snapshots |
| `Setup` | `ConfigurationMonitoring.ReadWrite.All`, `Application.ReadWrite.All`, `AppRoleAssignment.ReadWrite.All` | Provision/grant UTCM service principal permissions |

### Delegated examples

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

# Use device code instead of browser sign-in
Connect-TBTenant -UseDeviceCode
```

## Unattended Authentication

Use unattended authentication when TenantBaseline runs from Azure Automation, GitHub Actions, containers, or other schedulers.

### Managed identity

```powershell
# System-assigned managed identity
Connect-TBTenant -Identity

# User-assigned managed identity
Connect-TBTenant -Identity -ClientId '11111111-1111-1111-1111-111111111111'
```

### App certificate

```powershell
Connect-TBTenant `
    -ClientId '11111111-1111-1111-1111-111111111111' `
    -TenantId 'contoso.onmicrosoft.com' `
    -CertificateThumbprint 'ABC123DEF456'
```

### Client secret

```powershell
$secret = ConvertTo-SecureString $env:TB_CLIENT_SECRET -AsPlainText -Force
$credential = [pscredential]::new('11111111-1111-1111-1111-111111111111', $secret)

Connect-TBTenant -ClientSecretCredential $credential -TenantId 'contoso.onmicrosoft.com'
```

### Pre-acquired access token

```powershell
$token = ConvertTo-SecureString $env:TB_GRAPH_ACCESS_TOKEN -AsPlainText -Force
Connect-TBTenant -AccessToken $token
```

`Get-TBConnectionStatus` now includes an `AuthType` field so scripts can confirm whether they are running delegated or unattended.

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

## Notes

- Delegated modes use `Scenario`, `Scopes`, and `IncludeDirectoryMetadata`.
- Unattended modes rely on the token or application identity you supply; `Scenario` scopes are not applied in those parameter sets.
- UTCM still requires the Microsoft first-party UTCM service principal to be provisioned and granted the right workload permissions in the tenant.
- Some tenants may require additional permission validation for app-only access depending on how the UTCM backend enforces authorization. Validate unattended auth in your target environment before relying on it in production.
