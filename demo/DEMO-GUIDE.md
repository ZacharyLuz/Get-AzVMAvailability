# Get-AzVMAvailability — Live Demo Guide

**Version:** 1.9.0 | **Duration:** ~30 minutes + Q&A | **Audience:** Internal Microsoft / External Customers

---

## Before You Start

### Prerequisites

- PowerShell 7+
- `Az.Compute`, `Az.Resources` modules installed
- Logged in: `Connect-AzAccount`
- Active subscription with VM quota
- `ImportExcel` module (optional, for XLSX export in Scenario 7)

### Pre-flight Checklist

```powershell
# Verify login and subscription
Get-AzContext | Select-Object Account, Subscription, Tenant

# Confirm the module is available
Get-Module Az.Compute -ListAvailable | Select-Object Name, Version -First 1
```

### Terminal Setup

- Use **Windows Terminal** or **VS Code integrated terminal** (Unicode icons render correctly)
- Set terminal width to **140+ characters** for best table formatting
- Have the script directory as your working directory

---

## Demo Flow

```
Act 1: "Where Can I Deploy?"     (~10 min)  Scenarios 1-3
Act 2: "What Should I Deploy?"   (~10 min)  Scenarios 4-6
Act 3: "Automation & Export"     (~5 min)   Scenario 7
Closing: Recap + Q&A             (~5 min)
```

---

## Opening (1 minute)

### Talking Points

> "How many times have you tried to deploy a VM and gotten a capacity error? Or a customer calls and says 'I need a D4s_v5 in East US' — and you have no idea if it's available, constrained, or restricted in their subscription?"
>
> "This tool answers that question in seconds. It scans Azure regions for VM SKU availability, capacity status, quota, pricing, and image compatibility — all from a single PowerShell command."
>
> "Let me show you."

---

## Act 1: "Where Can I Deploy?"

### Scenario 1: Interactive Prompt Mode (~4 min, LIVE)

**The story:** First-time user, no idea what parameters exist. Just run it.

```powershell
.\Get-AzVMAvailability.ps1
```

**What to do:**
1. Run the command above — it will prompt for subscription and region
2. Select your subscription from the list
3. Type a region (e.g., `eastus`) when prompted
4. Let the scan complete — point out the color-coded output as it appears

**Talking points:**
- "Zero parameters needed. The tool walks you through everything."
- "Notice the color coding — green means OK capacity, yellow means limited or constrained, red means blocked."
- "Each row shows a VM family with its purpose — D is general purpose, E is memory optimized, NC is GPU compute."
- "The quota column shows how many vCPUs you have available vs. your limit in this subscription."

**What to highlight on screen:**
- The subscription selection prompt
- Color-coded capacity status for each family
- The quota utilization column (e.g., `12/100 vCPUs`)
- Zone availability information

**Transition:**
> "That's great for exploring, but what if you already know exactly what you need?"

---

### Scenario 2: Targeted Multi-Region Scan (~3 min, LIVE)

**The story:** Customer needs D-series VMs and wants to compare three regions.

```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus","westus2","centralus" -FamilyFilter "D" -NoPrompt
```

**Talking points:**
- "Three regions scanned in parallel — this finishes in about 5 seconds."
- "We filtered to just D-series, so the output is focused. No noise."
- "`-NoPrompt` skips all interactive questions — perfect for when you know what you want."
- "Look at the comparison — you can instantly see which region has the best capacity for D-series."

**What to highlight on screen:**
- The parallel scan timing in the header
- Side-by-side capacity status across the three regions
- Any differences in availability between regions

**Transition:**
> "Typing three region names works, but we have shortcuts for common patterns."

---

### Scenario 3: Region Presets (~2 min, LIVE)

**The story:** Scan all major US regions in one shot.

```powershell
.\Get-AzVMAvailability.ps1 -RegionPreset USMajor -FamilyFilter "D","E" -NoPrompt
```

**Talking points:**
- "`USMajor` expands to the top 5 US regions: East US, East US 2, Central US, West US, West US 2."
- "We also have presets for Europe, Asia-Pacific, and even sovereign clouds — USGov and China."
- "Combining presets with family filters gives you a focused, scannable view across your infrastructure footprint."

**What to highlight on screen:**
- The preset expansion in verbose output (5 regions in one parameter)
- D and E family results across all 5 regions

**Sidebar — Sovereign Cloud (mention, don't demo):**
> "For government customers, we have a `USGov` preset that auto-sets the Azure Government environment. Same tool, same syntax. China cloud works the same way."

**Transition:**
> "Now you know WHERE you can deploy. Let's talk about WHAT you should deploy — and what it'll cost."

---

## Act 2: "What Should I Deploy?"

### Scenario 4: Live Pricing (~3 min, LIVE or pre-captured)

**The story:** Manager asks "what will this cost?" You answer in real time.

```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus" -FamilyFilter "D" -ShowPricing -NoPrompt
```

**Talking points:**
- "`-ShowPricing` adds hourly and monthly cost columns to every SKU."
- "The tool auto-detects your pricing tier — if you have an Enterprise Agreement, MCA, or CSP contract, you'll see your negotiated rates instead of retail."
- "If negotiated rates aren't accessible, it falls back to the public Retail Pricing API — still accurate, just not your discounted rate."
- "Monthly pricing uses the industry-standard 730 hours per month."

**What to highlight on screen:**
- The pricing columns ($/hr, $/mo) next to each SKU
- The pricing source indicator (EA/MCA vs. Retail)
- Cost differences between SKU variants (e.g., D4s_v5 vs. D4as_v5)

**Transition:**
> "Cost and capacity are covered. But have you ever deployed a VM and *then* found out your image doesn't support that SKU? Gen1 vs Gen2, x64 vs ARM64..."

---

### Scenario 5: Image Compatibility (~3 min, LIVE)

**The story:** Customer wants to deploy Ubuntu ARM64 — which SKUs actually support it?

```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus" -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest" -EnableDrillDown -NoPrompt
```

**Talking points:**
- "`-ImageURN` specifies a VM image using the standard Publisher:Offer:Sku:Version format."
- "The tool detects that this Ubuntu image is ARM64 and Gen2 — then flags every SKU that can't run it."
- "You'll see Gen and Arch columns in the drill-down, plus an `Img` compatibility indicator."
- "This catches deployment failures BEFORE you waste 10 minutes on a failed `az vm create`."

**What to do during drill-down:**
1. When prompted for family filter, type `D` to focus on D-series
2. Point out which SKUs show compatible vs. incompatible for the ARM64 image
3. Highlight that only `Dps` variants (Ampere ARM64) are compatible

**What to highlight on screen:**
- The Gen/Arch columns showing Gen2/ARM64
- Compatible vs. incompatible SKU indicators
- The automatic image detection (no manual Gen/Arch lookup needed)

**Note:** If the audience isn't familiar with ARM64, you can swap to a Gen2 x64 image instead:
```powershell
# Alternative: Windows Server 2022 Gen2
.\Get-AzVMAvailability.ps1 -Region "eastus" -ImageURN "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest" -EnableDrillDown -NoPrompt
```

**Transition:**
> "Now for the scenario that comes up most in support calls. A customer's D4s_v3 is constrained — what should they migrate to?"

---

### Scenario 6: Recommend Mode — The Money Scenario (~4 min, LIVE)

**The story:** Customer calls: "My Standard_D4s_v3 is capacity constrained in East US. What do I do?"

```powershell
.\Get-AzVMAvailability.ps1 -Recommend "Standard_D4s_v3" -Region "eastus","westus2" -ShowPricing -TopN 10 -NoPrompt
```

**Talking points:**
- "This is the scenario that saves the most time. Customer gives you a SKU name, you paste it in, and get a ranked list of alternatives in 30 seconds."
- "The scoring algorithm weighs 6 dimensions: vCPU count (25 points), memory (25), family match (20), VM generation (13), CPU architecture (12), and premium IO support (5). Max score is 100."
- "A score of 95-100 means it's nearly identical. 80-90 means same family, slightly different specs. Below 70, you're crossing into different families."
- "Adding `-ShowPricing` lets you immediately see if the alternative is cheaper or more expensive."
- "We're scanning two regions here — so you can also tell the customer 'Your SKU is constrained in East US but has full capacity in West US 2.'"

**What to highlight on screen:**
- The similarity scores in the Score column
- The target SKU profile at the top (vCPU, memory, family)
- Alternatives ranked by score with pricing comparison
- Capacity status of each alternative in each region

**Transition:**
> "Everything we've seen outputs to the terminal. But what about automation pipelines and executive reports?"

---

## Act 3: "Automation & Export"

### Scenario 7: JSON + Excel Export (~3 min, LIVE or pre-captured)

**Part A — JSON for automation:**

```powershell
.\Get-AzVMAvailability.ps1 -Recommend "D4s_v5" -Region "eastus" -JsonOutput -NoPrompt
```

**Talking points:**
- "`-JsonOutput` emits structured JSON to stdout — pipe it to a file, parse it in a CI pipeline, or feed it to another tool."
- "The JSON includes the target SKU profile, all scored alternatives, and their capacity status."
- "This makes it trivial to integrate with Azure DevOps, GitHub Actions, or any automation framework."

**What to highlight on screen:**
- Clean JSON structure (no console colors, no interactive prompts)
- Machine-readable fields (score, capacity status, vCPU, memoryGB)

**Part B — Excel for stakeholders:**

```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus" -FamilyFilter "D" -ShowPricing -AutoExport -OutputFormat XLSX -NoPrompt
```

**Talking points:**
- "`-AutoExport` skips the export prompt and writes the file immediately."
- "The Excel workbook has three worksheets: Summary (color-coded capacity matrix), Details (every SKU with specs), and Legend (status definitions)."
- "Conditional formatting is built in — green for OK, yellow for limited, red for restricted. You can hand this directly to a stakeholder."
- "If the `ImportExcel` module isn't installed, it gracefully falls back to CSV."

**What to highlight on screen:**
- The export path printed at the end
- Open the XLSX and show the three worksheets (if pre-captured, have a screenshot ready)

**Sidebar:**
> "This also works in Azure Cloud Shell — it detects the environment and adjusts the export path automatically."

---

## Closing (5 minutes)

### Recap

> "Let me quickly recap what we covered:"

| Capability | How |
|---|---|
| Interactive exploration | Just run the script, no parameters |
| Multi-region comparison | `-Region` with multiple values or `-RegionPreset` |
| Family filtering | `-FamilyFilter "D","E"` |
| Live pricing | `-ShowPricing` (auto-detects EA/retail) |
| Image compatibility | `-ImageURN` with drill-down |
| SKU recommendations | `-Recommend "SKU_Name"` with scoring |
| JSON automation | `-JsonOutput` for pipelines |
| Excel export | `-AutoExport -OutputFormat XLSX` for stakeholders |
| Sovereign cloud | `-RegionPreset USGov` or `-Environment AzureUSGovernment` |

### Key Differentiators

- **Speed:** Parallel region scanning — 5 regions in ~5 seconds
- **Depth:** Capacity + quota + pricing + image compat in one view
- **Flexibility:** Interactive for exploring, parameterized for automation
- **No Azure CLI dependency:** Pure Az PowerShell modules
- **Open source:** MIT licensed, contributions welcome

### Q&A Guidance

Common questions and how to answer them:

| Question | Answer |
|---|---|
| "Does this work in Cloud Shell?" | Yes, auto-detects and adjusts paths and icons. |
| "Can I scan all regions?" | Yes, use `-RegionPreset Global` or pass all region codes. Keep in mind more regions = longer scan. |
| "Do I need special permissions?" | Reader role is sufficient. Billing Reader adds negotiated pricing. |
| "Does it support sovereign clouds?" | Yes — USGov and China presets auto-set the environment. |
| "Can I filter to a specific SKU?" | Yes, use `-SkuFilter "Standard_D4s*"` with wildcards. |
| "What if ImportExcel isn't installed?" | Falls back to CSV automatically. |
| "Is this safe to run in production?" | It's read-only — no resource modifications, only API reads. |

### Project Links

- **Repository:** [github.com/zacharyluz/Get-AzVMAvailability](https://github.com/zacharyluz/Get-AzVMAvailability)
- **Issues / Feature Requests:** via GitHub Issues
- **License:** MIT

---

## Appendix: Pre-Captured Output Tips

For scenarios that take longer (pricing lookups, large region scans), consider preparing screenshots or terminal recordings:

1. **Pricing (Scenario 4):** First pricing call can take 5-10 seconds while the Retail API responds. Run once before the demo to warm up your session.
2. **Excel (Scenario 7B):** Have a pre-generated XLSX file open in Excel as a backup. The conditional formatting is the showpiece.
3. **Image drill-down (Scenario 5):** If your subscription has restricted SKUs, the contrast between compatible and incompatible rows is more dramatic — pick a subscription where you'll see both.

### Recommended Demo Order Adjustments

- **Short version (15 min):** Scenarios 1, 2, 6, 7A — skip presets, pricing, and image compat.
- **Executive version (10 min):** Scenarios 2, 6, 7B — targeted results, recommendations, Excel handoff.
- **Engineer version (20 min):** Scenarios 2, 4, 5, 6 — skip interactive prompts, focus on depth.
