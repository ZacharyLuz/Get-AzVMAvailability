## Description

Add fleet safety warnings, CPU/disk hardware columns, and architecture filtering to Recommend mode. When recommendations include mixed CPU vendors, storage interfaces, or temp disk configurations, the tool warns users about operational implications before deploying a heterogeneous fleet.

## Changes

### New Parameters
- **`-AllowMixedArch`** — Opt-in to include ARM64 candidates when targeting x64 (or vice versa). Default now filters to the target's architecture.

### New Helper Functions
- **`Get-ProcessorVendor`** — Determines Intel/AMD/ARM from SKU naming conventions (handles A-family exclusion, p-before-a precedence)
- **`Get-DiskCode`** — Returns storage shortcode: `NV+T`, `NVMe`, `SC+T`, or `SCSI`

### Enhanced `Get-SkuCapabilities`
- Now extracts `TempDiskGB`, `AcceleratedNetworkingEnabled`, and `NvmeSupport` alongside existing HyperV generation and CPU architecture

### Recommend Mode Enhancements
- **CPU column** — Shows Intel/AMD/ARM for each candidate
- **Disk column** — Shows storage config shortcode
- **Architecture filtering** — Candidates excluded if arch doesn't match target (override with `-AllowMixedArch`)
- **Fleet safety warnings** — Detects and warns about:
  - Mixed architectures (x64 + ARM64) requiring separate OS images
  - Mixed CPU vendors with varying performance characteristics
  - Mixed temp disk configurations (different drive paths)
  - Mixed storage interfaces (NVMe vs SCSI driver differences)
  - Mixed accelerated networking support
- **Disk codes legend** added to output footer
- **JSON output** now includes `cpu`, `disk`, `tempDiskGB`, `accelNet` fields and a `warnings` array

## Testing

- 13 new tests in `tests/FleetSafety.Tests.ps1` covering `Get-ProcessorVendor` (Intel, AMD, ARM, A-family exclusion, p/a precedence) and `Get-DiskCode` (all 4 combinations)
- Syntax validated via `[scriptblock]::Create()`
- No breaking changes to existing workflows

## Type of Change

- [x] New feature (non-breaking change that adds functionality)
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] Code quality (refactoring, comments, tests)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
