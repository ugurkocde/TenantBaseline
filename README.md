# TenantBaseline

A PowerShell module for Microsoft 365 tenant configuration monitoring, drift detection, and compliance reporting -- powered by the Microsoft Graph UTCM beta API.

[![PSGallery Version](https://img.shields.io/powershellgallery/v/TenantBaseline?label=PSGallery&color=blue)](https://www.powershellgallery.com/packages/TenantBaseline)
[![PowerShell 7.2+](https://img.shields.io/badge/PowerShell-7.2%2B-blue)](https://github.com/PowerShell/PowerShell)
[![CI](https://github.com/ugurkocde/TenantBaseline/actions/workflows/ci.yml/badge.svg)](https://github.com/ugurkocde/TenantBaseline/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Authentication](#authentication)
- [Command Reference](#command-reference)
- [Common Workflows](#common-workflows)
- [API Limits](#api-limits)
- [Project Structure](#project-structure)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

TenantBaseline wraps the Microsoft Graph Unified Tenant Configuration Management (UTCM) beta API into a set of PowerShell cmdlets that make it straightforward to define baselines, detect drift, capture snapshots, and generate compliance reports for your Microsoft 365 tenant.

The module covers 268 resource types across M365 workloads including Entra ID, Exchange Online, Microsoft Intune, Microsoft Teams, SharePoint, OneDrive, and more. Whether you are an IT administrator tracking Conditional Access policy changes or a compliance team auditing Intune device configurations, TenantBaseline provides the tooling to monitor and document tenant state.

---

## Features

- **Connection Management** -- Connect to Microsoft Graph with scenario-based scoping that requests only the permissions you need.
- **Automated Setup** -- Provision and configure the UTCM service principal with guided permission granting, including manual remediation steps for provider-specific permissions.
- **Monitor Management** -- Create, update, and remove configuration monitors that track resources against a known-good baseline.
- **Drift Detection** -- Detect configuration drift with filtering by monitor or resource type, and get aggregated summaries grouped by status and workload.
- **Baseline Export/Import** -- Export baselines to JSON for version control or migration, and import them to seed new monitors.
- **Configuration Snapshots** -- Capture point-in-time tenant configuration snapshots, wait for completion, and export data before the 7-day expiry.
- **Compliance Reporting** -- Generate HTML drift reports, interactive dashboards with embedded timelines, and formatted documentation for compliance review.
- **Interactive Console** -- A menu-driven TUI (`Start-TBInteractive`) with guided workflows, input validation, and resource type pickers for all module operations.

---

## Requirements

| Requirement | Details |
|---|---|
| PowerShell | 7.2 or later (Core edition) |
| Module dependency | `Microsoft.Graph.Authentication` v2.0.0+ |
| Tenant access | Entra ID tenant with Global Administrator or appropriate admin roles |

---

## Installation

**From the PowerShell Gallery (recommended):**

```powershell
Install-Module -Name TenantBaseline -Scope CurrentUser
```

**Manual clone for contributors:**

```powershell
git clone https://github.com/ugurkocde/TenantBaseline.git
Import-Module ./tenantbaseline/src/TenantBaseline/TenantBaseline.psd1
```

---

## Quick Start

```powershell
# Connect with setup permissions (first time only)
Connect-TBTenant -Scenario Setup

# Provision the UTCM service principal and grant permissions
Install-TBServicePrincipal

# Reconnect with day-to-day permissions
Connect-TBTenant -Scenario Manage

# Create a monitor to track Conditional Access policies
New-TBMonitor -DisplayName 'CA Monitor' -Resources @(
    @{ resourceType = 'microsoft.entra.conditionalaccesspolicy'; displayName = 'CA Policy' }
)

# Check for configuration drift
Get-TBDrift

# Generate an HTML drift report
New-TBDriftReport -OutputPath ./drift-report.html
```

---

## Authentication

TenantBaseline uses interactive/delegated authentication via `Connect-MgGraph`. No custom app registration is required. The module requests the minimum scopes needed for each scenario.

| Scenario | Scopes | Use case |
|---|---|---|
| `ReadOnly` | `ConfigurationMonitoring.Read.All` | View monitors, drifts, and snapshots |
| `Manage` | `ConfigurationMonitoring.ReadWrite.All` | Create/update monitors, snapshots, and reports |
| `Setup` | `ConfigurationMonitoring.ReadWrite.All`, `Application.ReadWrite.All` | One-time UTCM service principal provisioning |

For details, see [docs/Authentication.md](docs/Authentication.md).

---

## Command Reference

### Connection

| Command | Description |
|---|---|
| `Connect-TBTenant` | Connects to Microsoft Graph with scenario-based scopes |
| `Disconnect-TBTenant` | Disconnects from Microsoft Graph and clears session state |
| `Get-TBConnectionStatus` | Returns the current connection status, tenant, and granted scopes |

### Setup

| Command | Description |
|---|---|
| `Install-TBServicePrincipal` | Provisions the UTCM service principal and grants workload permissions |
| `Test-TBServicePrincipal` | Checks whether the UTCM service principal exists in the tenant |
| `Grant-TBServicePrincipalPermission` | Grants permissions using a resource-aware plan with manual remediation guidance |
| `Get-TBPermissionPlan` | Builds a permission plan showing auto-grantable and manual-step permissions |

### Monitor Management

| Command | Description |
|---|---|
| `New-TBMonitor` | Creates a configuration monitor that tracks resources for drift |
| `Get-TBMonitor` | Gets one or all configuration monitors |
| `Set-TBMonitor` | Updates display name, description, status, or baseline of a monitor |
| `Remove-TBMonitor` | Deletes a configuration monitor |
| `Get-TBMonitorResult` | Gets monitoring run results and errors, optionally filtered by monitor |

### Drift Detection

| Command | Description |
|---|---|
| `Get-TBDrift` | Lists detected configuration drifts, filterable by drift ID or monitor |
| `Get-TBDriftSummary` | Aggregates drifts by resource type, monitor, and status |

### Baseline

| Command | Description |
|---|---|
| `Get-TBBaseline` | Gets the baseline configuration from a monitor |
| `Export-TBBaseline` | Exports a monitor baseline to a local JSON file |
| `Import-TBBaseline` | Imports a baseline JSON file and returns resources for piping to `New-TBMonitor` |

### Snapshot

| Command | Description |
|---|---|
| `New-TBSnapshot` | Creates a snapshot job for specified resource types |
| `Get-TBSnapshot` | Gets one or all snapshot jobs |
| `Remove-TBSnapshot` | Deletes a snapshot job |
| `Wait-TBSnapshot` | Polls until a snapshot job reaches a terminal state |
| `Export-TBSnapshot` | Downloads snapshot content to a local JSON file before expiry |

### Report

| Command | Description |
|---|---|
| `New-TBDriftReport` | Generates an HTML or JSON drift report for compliance review |
| `New-TBDashboard` | Generates an interactive HTML dashboard with drift timelines and monitor details |
| `New-TBDocumentation` | Generates formatted documentation for compliance review or wiki embedding |

### Interactive

| Command | Description |
|---|---|
| `Start-TBInteractive` | Launches the menu-driven management console with guided workflows |

---

## Common Workflows

### First-Time Setup

```powershell
Connect-TBTenant -Scenario Setup
Install-TBServicePrincipal
Grant-TBServicePrincipalPermission -ResourceTypes @('microsoft.entra.conditionalaccesspolicy')
```

### Daily Monitoring

```powershell
Connect-TBTenant -Scenario Manage
Get-TBDriftSummary
New-TBDriftReport -OutputPath ./daily-drift.html
```

### Baseline Export and Import

```powershell
# Export baseline from an existing monitor
Export-TBBaseline -MonitorId $sourceId -OutputPath ./baseline.json

# Import and create a new monitor from the exported baseline
$resources = Import-TBBaseline -Path ./baseline.json
New-TBMonitor -DisplayName 'Imported Monitor' -Resources $resources
```

### Snapshot Capture

```powershell
$snapshot = New-TBSnapshot -DisplayName 'Pre Change' -Resources @('microsoft.entra.conditionalaccesspolicy')
Wait-TBSnapshot -SnapshotId $snapshot.id
Export-TBSnapshot -SnapshotId $snapshot.id -OutputPath ./snapshot.json
```

---

## API Limits

| Limit | Value |
|---|---|
| Monitors per tenant | 30 |
| Daily monitored resources | 800 |
| Monitoring cycle interval | 6 hours |
| Snapshot retention | 7 days |

For details, see [docs/API-Limits.md](docs/API-Limits.md).

---

## Project Structure

```
tenantbaseline/
  .github/workflows/   CI (lint + Pester) and PSGallery release
  build/               Build and packaging scripts
  docs/                Documentation (Getting Started, Auth, API Limits, Migration)
  src/TenantBaseline/  Module source
    Public/            26 exported cmdlets organized by functional area
    Private/           Internal helpers (API wrapper, interactive menu system)
    Data/              Resource type registry and workload metadata
    en-US/             Help content
  tests/
    Unit/              Pester unit tests (Public + Private)
    Fixtures/          Mock API response data
    Integration/       Integration test stubs
```

---

## Documentation

| Guide | Description |
|---|---|
| [Getting Started](docs/Getting-Started.md) | Installation, prerequisites, and first steps |
| [Authentication](docs/Authentication.md) | Auth scenarios, scopes, and delegated sign-in flow |
| [API Limits](docs/API-Limits.md) | UTCM quota and throttling reference |
| [Migration Guide](docs/Migration-Guide.md) | Upgrade notes and PowerShell 7.2+ compatibility |

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-change`)
3. Write or update tests for new functionality
4. Run lint and tests locally:
   ```powershell
   pwsh build/build.ps1
   ```
   The build script runs PSScriptAnalyzer and the full Pester test suite.
5. Submit a pull request

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
