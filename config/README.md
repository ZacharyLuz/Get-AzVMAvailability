# config/

This folder holds reference copies of the configuration sections from `Get-AzVMAvailability.ps1`. It exists for **documentation and navigation purposes only**.

## Contents

| File | Description |
|------|-------------|
| `config.ps1` | Reference copy of lines 249–559: the `[CmdletBinding()]` param block, `$ProgressPreference`, FleetFile/Fleet input normalization, `#region Configuration constants`, `$MinScore` default, and parameter mappings. |

## Important Notes

- **Do not execute any file in this folder directly.** The files are extracted reference copies and will fail if run independently — they depend on the full script context.
- **The authoritative source is always `Get-AzVMAvailability.ps1`** in the repository root. If there is any discrepancy between a file here and the main script, the main script is correct.
- These copies are updated manually when the main script changes. They may lag behind the main script between updates.
