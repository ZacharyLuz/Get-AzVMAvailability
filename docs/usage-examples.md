# Usage Examples

[← Back to README](../README.md)

> **💡 Tip**: When copying multi-line commands, ensure backticks (`` ` ``) at the end of each line are preserved. If copying from GitHub, use the "Copy" button in code blocks.

## Check Specific Regions
```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus","westus2","centralus"
```

## Azure Government
```powershell
# Connected to Gov cloud — defaults to usgovvirginia, usgovtexas, usgovarizona
Connect-AzAccount -Environment AzureUSGovernment
Get-AzVMAvailability -NoPrompt

# Or specify Gov regions explicitly
Get-AzVMAvailability -Region "usgovvirginia","usgovtexas" -NoPrompt
```

## Check GPU SKU Availability
```powershell
# Multi-line with backticks for readability
.\Get-AzVMAvailability.ps1 `
    -Region "eastus","eastus2","southcentralus" `
    -FamilyFilter "NC","ND","NV"
```

## Export to Specific Location
```powershell
.\Get-AzVMAvailability.ps1 `
    -ExportPath "C:\Reports" `
    -AutoExport `
    -OutputFormat XLSX
```

## Check Specific SKUs with Pricing
```powershell
# Pricing auto-detects negotiated rates (EA/MCA/CSP), falls back to retail
.\Get-AzVMAvailability.ps1 `
    -Region "eastus","westus2" `
    -SkuFilter "Standard_D*_v5" `
    -ShowPricing
```

## Full Parameter Example
```powershell
# Multi-line format with backticks for readability
.\Get-AzVMAvailability.ps1 `
    -SubscriptionId "your-subscription-id" `
    -Region "eastus","westus2","centralus" `
    -ExportPath "C:\Reports" `
    -AutoExport `
    -EnableDrillDown `
    -FamilyFilter "D","E","M" `
    -OutputFormat "XLSX" `
    -UseAsciiIcons
```
