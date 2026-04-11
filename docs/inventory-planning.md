# Inventory Planning Quick Start

[← Back to README](../README.md)

Validate whether your entire VM deployment can be provisioned in a target region.

## Step 1: Create your inventory file

**Option A — Generate a template** (easiest):
```powershell
.\Get-AzVMAvailability.ps1 -GenerateInventoryTemplate
# Creates inventory-template.csv and inventory-template.json in current directory
# Edit with your actual SKUs and quantities
```

**Option B — Write a CSV** (Excel / text editor):
```csv
SKU,Qty
Standard_D2s_v5,17
Standard_D4s_v5,4
Standard_D8s_v5,5
```

**Option C — Write a JSON file**:
```json
[
  { "SKU": "Standard_D2s_v5", "Qty": 17 },
  { "SKU": "Standard_D4s_v5", "Qty": 4 },
  { "SKU": "Standard_D8s_v5", "Qty": 5 }
]
```

> **Column names are flexible:** `SKU`, `Name`, or `VmSize` for the SKU column; `Qty`, `Quantity`, or `Count` for quantity. Duplicate SKU rows are summed automatically. The `Standard_` prefix is optional.

## Step 2: Run the scan

```powershell
.\Get-AzVMAvailability.ps1 -InventoryFile .\inventory-template.csv -Region "eastus" -NoPrompt
```

## Step 3: Read the verdict

The output shows per-SKU capacity status, per-family quota pass/fail (Used/Available/Limit), and an overall **PASS/FAIL** verdict.
