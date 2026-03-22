# ui/

This folder contains reference copies of UI-related sections extracted from `Get-AzVMAvailability.ps1` for **documentation and navigation purposes only**.

## Contents

| File | Source Lines | Description |
|------|-------------|-------------|
| `InputHandler.ps1` | 2665–3060 | Interactive subscription/region selection prompts, options menus, image URN selection, and drill-down mode prompts |
| `OutputFormatter.ps1` | 3062–3700 | Main scan results rendering loop, table headers, color-coded status display, zone/restriction/pricing columns, and status key/legend output |
| `ExportHandler.ps1` | 4047–4592 | XLSX and CSV export logic, Excel worksheet formatting, export path selection, and final export summary output |

## Important Notes

- **Files are reference copies only** — they cannot be executed independently. Each section depends on variables, functions, and state established earlier in the full script.
- **The authoritative source is always `Get-AzVMAvailability.ps1`** in the repository root. If there is any discrepancy between a file here and the main script, the main script is correct.
- These copies are updated manually; they may temporarily lag behind the main script.
