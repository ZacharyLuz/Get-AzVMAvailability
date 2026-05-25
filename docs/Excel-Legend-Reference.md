# Excel Export Legend Reference

This document explains the Legend worksheet included in the Excel (XLSX) export from `Get-AzVMAvailability.ps1`.

## Important Framing

The Excel export keeps the legacy **Capacity** column name for compatibility, but the value is derived from ARM `Microsoft.Compute/skus` restriction metadata. `OK` means no ARM SKU restriction was returned for the scanned scope. It does not prove live physical capacity, and deployment can still fail because of quota, placement, policy, or transient platform allocation.

---

## Status Format: Understanding `(X/Y)`

When you see a value like `OK (5/8)` in the Summary sheet, here's what it means:

| Component  | Meaning                                                     |
| ---------- | ----------------------------------------------------------- |
| **Status** | The overall ARM SKU restriction status (OK, LIMITED, etc.)  |
| **X**      | Number of SKUs with no returned ARM restriction record      |
| **Y**      | **Total** number of SKUs in that family for that region     |

### Examples

| Value                        | Interpretation                                                    |
| ---------------------------- | ----------------------------------------------------------------- |
| `OK (5/8)`                   | OK status overall; 5 of 8 SKUs returned no ARM restriction record |
| `LIMITED (2/10)`             | LIMITED status; 2 of 10 SKUs returned no ARM restriction record   |
| `ZONE-LIMITED (3/6)` | Zone restriction signal; 3 of 6 SKUs returned no ARM restriction  |
| `N/A`                        | This VM family is not available in this region                    |

---

## SKU Restriction Status Codes

| Status                   | Color    | Description                                                                                     |
| ------------------------ | -------- | ----------------------------------------------------------------------------------------------- |
| **OK**                   | 🟢 Green  | No ARM SKU restriction returned for the scanned scope                                           |
| **LIMITED**              | 🟡 Yellow | Subscription/SKU access restriction applies; may require support or quota review                |
| **ZONE-LIMITED** | 🟡 Yellow | Some zones returned ARM restriction records, others did not                                     |
| **PARTIAL**              | 🟡 Yellow | Mixed zone restriction state; some zones OK, others restricted                                  |
| **RESTRICTED**           | 🔴 Red    | Blocking ARM restriction returned for this region/subscription                                  |
| **N/A**                  | ⚪ Gray   | SKU family not available in this region                                                         |

---

## Summary Sheet Columns

| Column                | Description                                                    |
| --------------------- | -------------------------------------------------------------- |
| **Family**            | VM family identifier (e.g., Dv5, Ev5, Mv2)                     |
| **Total_SKUs**        | Total number of SKUs scanned across all regions                |
| **SKUs_OK**           | Number of SKUs with no returned ARM restriction (OK status)    |
| **\<Region\>_Status** | Restriction status for that region with `(Unrestricted/Total)` count |

---

## Details Sheet Columns

| Column           | Description                                                  |
| ---------------- | ------------------------------------------------------------ |
| **Family**       | VM family identifier                                         |
| **SKU**          | Full SKU name (e.g., `Standard_D2s_v5`)                      |
| **Region**       | Azure region code (e.g., `eastus`, `westeurope`)             |
| **vCPU**         | Number of virtual CPUs                                       |
| **MemGiB**       | Memory in GiB                                                |
| **Zones**        | Availability zones where SKU is available (e.g., `1,2,3`)    |
| **Capacity**     | Legacy field name containing ARM SKU restriction status      |
| **Restrictions** | ARM SKU restriction reason codes and messages                |
| **QuotaAvail**   | Available vCPU quota for this family (Limit - Current Usage) |
| **$/Hr**         | Hourly price (if `-ShowPricing` enabled)                     |
| **$/Mo**         | Monthly price estimate (if `-ShowPricing` enabled)           |

---

## Color Coding

The Excel export uses conditional formatting to help you quickly identify status:

| Color               | Meaning                   | Action                                       |
| ------------------- | ------------------------- | -------------------------------------------- |
| 🟢 **Green**         | No ARM restriction returned | Validate quota, placement, and deployment dependencies |
| 🟡 **Yellow/Orange** | ARM restriction signal present | Review restriction reason, zones, and SKU access |
| 🔴 **Red**           | Blocking ARM restriction returned | Choose alternative SKU or region             |
| ⚪ **Gray**          | Not applicable            | Family/SKU not returned in this region       |

---

## What This Does Not Prove

The Excel status cells do not confirm that Azure can allocate the VM at deployment time. They also do not replace quota checks, placement scores, capacity reservations, policy validation, or an actual deployment/probe.

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│  STATUS (X/Y) = X SKUs unrestricted by ARM out of Y total   │
├─────────────────────────────────────────────────────────────┤
│  OK              → No ARM restriction returned              │
│  LIMITED         → Subscription/SKU access restriction      │
│  CAPACITY-CONST  → Some zones returned restrictions         │
│  RESTRICTED      → Blocking ARM restriction returned        │
│  N/A             → Not offered in this region               │
├─────────────────────────────────────────────────────────────┤
│  🟢 Green = validate  │  🟡 Yellow = investigate            │
│  🔴 Red   = blocked   │  ⚪ Gray   = N/A                    │
└─────────────────────────────────────────────────────────────┘
```

---

## See Also

- [README.md](../README.md) - Main documentation
- [CHANGELOG.md](../CHANGELOG.md) - Version history
- Run `Get-Help .\Get-AzVMAvailability.ps1 -Full` for parameter details
