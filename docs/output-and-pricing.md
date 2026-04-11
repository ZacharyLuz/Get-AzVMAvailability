# Output & Pricing

[← Back to README](../README.md)

## Console Output (with Pricing)
```
====================================================================================
GET-AZVMAVAILABILITY v2.0.0
====================================================================================
SKU Filter: Standard_D2s_v5 | Pricing: Enabled

REGION: eastus
====================================================================================

SKU FAMILIES:
Family    SKUs  OK   Largest       Zones            Status     Quota   $/Hr    $/Mo
------------------------------------------------------------------------------------
D         1     0    2vCPU/8GB     ⚠ Zones 1,2,3   LIMITED    100     $0.10   $70

====================================================================================
MULTI-REGION CAPACITY MATRIX
====================================================================================

Family     | eastus          | eastus2
------------------------------------------------------------------------------------
D          | ⚠ LIMITED       | ✓ OK
```

## Pricing (Auto-Detection)

With `-ShowPricing`, the script automatically detects the best pricing source:

1. **First, tries negotiated pricing** (EA/MCA/CSP)
   - Uses Azure Cost Management API
   - Requires Billing Reader or Cost Management Reader role
   - Shows your actual discounted rates

2. **Falls back to retail pricing** if negotiated rates unavailable
   - Uses the public Azure Retail Prices API
   - No special permissions required
   - Shows Linux pay-as-you-go rates

> **Note**: You'll see which pricing source is being used in the console output.

## Excel Export
- Color-coded status cells (green/yellow/red)
- Filterable columns with auto-filter
- Alternating row colors
- Azure-blue header styling

## Status Legend

| Icon | Status               | Description                    |
| ---- | -------------------- | ------------------------------ |
| ✓    | OK                   | Full capacity available        |
| ⚠    | CAPACITY-CONSTRAINED | Limited in some zones          |
| ⚠    | LIMITED              | Subscription-level restriction |
| ⚡    | PARTIAL              | Mixed zone availability        |
| ✗    | RESTRICTED           | Not available                  |
