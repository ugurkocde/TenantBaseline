# Changelog

All notable changes to the TenantBaseline module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.5] - 2026-02-10

### Removed
- 3 undocumented Entra ID resource types: attributeset, groupsnamingpolicy, groupssettings
- 9 undocumented Exchange Online resource types: addressbookpolicy, addresslist, clientaccessrule, eopprotectionpolicyrule, externalinoutlook, globaladdresslist, managementroleentry, offlineaddressbook, sweeprule
- 4 undocumented Security and Compliance resource types: auditconfigurationpolicy, autosensitivitylabelrule, dlpcompliancerule, sensitivitylabel
- 4 undocumented Teams resource types: channel, channeltab, orgwideappsettings, team

### Changed
- UTCM catalog now contains 249 resource types (was 269), verified against official Microsoft documentation for all workloads

## [0.1.4] - 2026-02-10

### Added
- Intune `deviceCleanupRule` resource type to UTCM catalog (269 total, 68 Intune)

## [0.1.3] - 2026-02-10

### Changed
- Repository and website links now shown on all menu screens, not just the main menu
- Updated links line casing to TenantBaseline.com and GitHub.com

## [0.1.2] - 2026-02-10

### Changed
- First-run flow now automatically checks UTCM service principal status and offers installation if missing

### Removed
- Quick Start prompt and monitor creation step from first-run flow
- `Invoke-TBQuickStart` private helper (no longer needed)

## [0.1.1] - 2026-02-10

### Added
- `TenantBaseline` alias that launches the interactive menu directly after install
- Updating instructions and version cleanup snippet in README
- Quick launch note in README Quick Start section

### Fixed
- CI module import check now validates functions and alias separately (Get-Command does not return aliases in non-interactive shells)

## [0.1.0] - 2026-02-10

### Added
- Canonical UTCM resource catalog artifact (`UTCMResourceCatalog.json`) with 269 resource types
- `Get-TBPermissionPlan` for hybrid auto/granular permission planning
- OData pagination helper for complete list retrieval (`Invoke-TBGraphPagedRequest`)
- Shared Fluent HTML style tokens used by dashboard, report, and documentation outputs
- Contract tests for UTCM catalog parity

### Changed
- Runtime baseline is now PowerShell 7.2+
- `Connect-TBTenant` now uses scenario-based least-privilege scope profiles (`ReadOnly`, `Manage`, `Setup`)
- `Grant-TBServicePrincipalPermission` supports `-ResourceType` and `-PlanOnly`
- Interactive resource registry now sources from tracked canonical UTCM catalog instead of hardcoded lists
- Interactive resource selection supports optional search filtering per workload
- List commands now retrieve all pages through `@odata.nextLink`

### Fixed
- Documentation and help scope names aligned with implementation (`ConfigurationMonitoring.ReadWrite.All`)
- `Install-TBServicePrincipal` now reports permission grant issues explicitly instead of always indicating full success
- Alias deprecation warnings are now tracked per monitor operation invocation instead of module lifetime
