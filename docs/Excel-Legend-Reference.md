# Excel Export Legend Reference

This document explains the Legend worksheet included in the Excel (XLSX) export from `Get-AzVMAvailability.ps1`.

---

## Status Format: Understanding `(X/Y)`

When you see a value like `OK (5/8)` in the Summary sheet, here's what it means:

| Component  | Meaning                                                     |
| ---------- | ----------------------------------------------------------- |
| **Status** | The overall capacity status (OK, LIMITED, etc.)             |
| **X**      | Number of SKUs with **full availability** (no restrictions) |
| **Y**      | **Total** number of SKUs in that family for that region     |

### Examples

| Value                        | Interpretation                                                    |
| ---------------------------- | ----------------------------------------------------------------- |
| `OK (5/8)`                   | OK status overall; 5 of 8 SKUs are fully available                |
| `LIMITED (2/10)`             | LIMITED status; only 2 of 10 SKUs deployable without restrictions |
| `CAPACITY-CONSTRAINED (3/6)` | Zone constraints; 3 of 6 SKUs have full availability              |
| `N/A`                        | This VM family is not available in this region                    |

---

## Capacity Status Codes

| Status                   | Color    | Description                                                                                     |
| ------------------------ | -------- | ----------------------------------------------------------------------------------------------- |
| **OK**                   | 🟢 Green  | Full capacity available - SKU can be deployed without restrictions                              |
| **LIMITED**              | 🟡 Yellow | Subscription-level restrictions apply - may require quota increase or support request           |
| **CAPACITY-CONSTRAINED** | 🟡 Yellow | Zone-level constraints - limited availability in some availability zones                        |
| **PARTIAL**              | 🟡 Yellow | Mixed zone availability - some zones OK, others restricted (e.g., Zone 1 OK, Zones 2,3 blocked) |
| **RESTRICTED**           | 🔴 Red    | SKU is not available for deployment in this region/subscription                                 |
| **N/A**                  | ⚪ Gray   | SKU family not available in this region                                                         |

---

## Summary Sheet Columns

| Column                | Description                                                    |
| --------------------- | -------------------------------------------------------------- |
| **Family**            | VM family identifier (e.g., Dv5, Ev5, Mv2)                     |
| **Total_SKUs**        | Total number of SKUs scanned across all regions                |
| **SKUs_OK**           | Number of SKUs with full availability (OK status)              |
| **\<Region\>_Status** | Capacity status for that region with `(Available/Total)` count |

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
| **Capacity**     | Current capacity status                                      |
| **Restrictions** | Any restrictions or capacity messages                        |
| **QuotaAvail**   | Available vCPU quota for this family (Limit - Current Usage) |
| **$/Hr**         | Hourly price (if `-ShowPricing` enabled)                     |
| **$/Mo**         | Monthly price estimate (if `-ShowPricing` enabled)           |

---

## Color Coding

The Excel export uses conditional formatting to help you quickly identify status:

| Color               | Meaning                | Action                                          |
| ------------------- | ---------------------- | ----------------------------------------------- |
| 🟢 **Green**         | Full availability      | Ready for deployment                            |
| 🟡 **Yellow/Orange** | Limited or constrained | Review restrictions; may need quota increase    |
| 🔴 **Red**           | Restricted             | Not available; choose alternative SKU or region |
| ⚪ **Gray**          | Not applicable         | Family/SKU not offered in this region           |

---

## Analogy: The Parking Garage

Think of each VM family as a multi-story parking garage:

| Excel Value                  | Parking Analogy                                                    |
| ---------------------------- | ------------------------------------------------------------------ |
| `OK (5/8)`                   | Garage is **open** - 5 of 8 floors have spots available            |
| `LIMITED (2/8)`              | Garage has **restrictions** - only 2 of 8 floors accessible to you |
| `CAPACITY-CONSTRAINED (3/8)` | Garage is **partially full** - only 3 floors have any spots left   |
| `RESTRICTED (0/8)`           | Garage is **closed** to your vehicle type                          |
| `N/A`                        | No garage exists at this location                                  |

---

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│  STATUS (X/Y) = Status with X available out of Y total SKUs │
├─────────────────────────────────────────────────────────────┤
│  OK              → Deploy with confidence                   │
│  LIMITED         → Check quota, may need support request    │
│  CAPACITY-CONST  → Some zones unavailable                   │
│  RESTRICTED      → Cannot deploy - pick another             │
│  N/A             → Not offered in this region               │
├─────────────────────────────────────────────────────────────┤
│  🟢 Green   = Go      │  🟡 Yellow = Caution                │
│  🔴 Red     = Stop    │  ⚪ Gray   = N/A                    │
└─────────────────────────────────────────────────────────────┘
```

---

## See Also

- [README.md](../README.md) - Main documentation
- [CHANGELOG.md](../CHANGELOG.md) - Version history
- Run `Get-Help .\Get-AzVMAvailability.ps1 -Full` for parameter details
