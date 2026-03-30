# Get-AzVMAvailability — Live Demo Guide

**Version:** 1.12.5 | **Duration:** ~40 minutes + Q&A | **Audience:** Internal Microsoft / External Customers

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
CRAWL — "Where Can I Deploy?"    (~15 min)  Scenarios 1-4
WALK  — "What Should I Deploy?"  (~15 min)  Scenarios 5-7
RUN   — "Automation & Export"    (~5 min)   Scenario 8
Closing: Contribution + Q&A       (~5 min)
```

> **Presenter note — 5S Anchors:** Every idea worth remembering hits at least three of Winston's five stickiness factors. They're called out per scenario below. **Symbol** = the color-coded table (green/yellow/red = instant status read, no explanation needed). **Slogan** = one-liner per scenario. **Surprise** = placement scores, 40-80% spot discounts. **Salient** = specific stats (5 regions in 5 seconds, 100-point scoring rubric). **Story** = the customer-problem frame that opens every scenario. The strongest scenarios — 4 and 7 — hit all five.

---

## Opening (1 minute)

> **Presenter note — Empowerment Promise:** Lead with what they will be able to *do* after this demo, not with what the tool *is*. State the promise explicitly within the first 60 seconds so every person in the room has a reason to stay. Don't start with a joke. Don't start with bios. Start here.

### Empowerment Promise (say this first)

> "By the end of this demo you'll be able to answer three questions that right now take you 20 minutes of portal-clicking or a support call: **Where can I deploy this VM? What should I migrate to if it's constrained? And exactly what will it cost?** — from a single PowerShell command, in under 30 seconds."

### Setup (say this second)

> "How many times have you tried to deploy a VM and gotten a capacity error with no explanation? Or a customer calls and says 'I need a D4s_v5 in East US' and you have no idea if it's available, constrained, or restricted in their subscription?"
>
> "This tool answers those questions in seconds — capacity status, quota, pricing, image compatibility, and ranked alternatives — all from one command."
>
> "Let me show you."

---

## CRAWL — "Where Can I Deploy?"

### Scenario 1: Interactive Prompt Mode (~5 min, LIVE)

**The story:** First-time user, no idea what parameters exist. Just run it.

> **5S:** Symbol (color-coded table), Story (first time user), Salient (zero parameters needed)
> **Slogan:** *"If you can type a region name, you can use this tool."*

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

**Step 2 — Introduce the drill-down:**

After the initial scan, show `-EnableDrillDown` for interactive per-SKU exploration — this is the core "zoom in" move.

```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus" -FamilyFilter "D" -EnableDrillDown
```

**Drill-down talking points:**
- "At any point after the scan, you can drill into a specific family for full per-SKU detail."
- "The drill-down adds Gen, Architecture, CPU, Disk, zone availability, and vCPU/memory columns."
- "This is the crawl: start broad across all families, then zoom into what matters."
- "Every scan you'll see later — pricing, image compat — also supports this drill-down."

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
> "Before we leave 'where', one more dimension: capacity data tells you whether a SKU is *reported* as available. Placement scores tell you how *likely* Azure is to actually fulfill the request."

---

### Scenario 4: Placement Scores (~3 min, LIVE)

**The story:** Capacity says OK, but you've seen allocations fail anyway. Placement scores give you Azure's confidence level.

> **5S:** Surprise (the thing you didn't know you needed), Salient (High/Medium/Low from Azure's own API), Story (capacity says OK but deploys still fail), Symbol (the new column that changes the decision), Slogan below
> **Slogan:** *"Capacity tells you the SKU exists. Placement tells you if Azure will actually give it to you."*

```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus","westus2","uksouth" -SkuFilter "Standard_D4s_v5","Standard_D8s_v5","Standard_D16s_v5" -ShowPlacement -DesiredCount 5 -NoPrompt
```

**Talking points:**
- "`-ShowPlacement` adds a High / Medium / Low allocation likelihood column from the Azure Placement Scores API."
- "Capacity status says whether a SKU is restricted or constrained. Placement says: *if you submit the deployment request right now, how likely is Azure to fulfill it?*"
- "High = confident allocation capacity. Medium = probably works. Low = consider a different region or SKU."
- "`-DesiredCount 5` means we want five VMs simultaneously — great for fleet planning where a partial allocation is worthless."
- "The score is live data from the API Azure uses for its own capacity planning."

**What to highlight on screen:**
- The Allocation Likelihood column (High/Medium/Low) appearing next to the capacity status
- Regional differences — the same SKU may be High in East US and Medium in UK South
- `-DesiredCount` changing the score vs. count of 1 (more VMs = higher bar for High)

**Note:** Requires "Compute Recommendations" RBAC role. If absent, the script skips placement scores and notes this in the output header.

**Transition:**
> "Now you know WHERE to deploy and how confident Azure is. Let's talk about WHAT to deploy — and what it'll cost."

---

## WALK — "What Should I Deploy?"

### Scenario 5: Live Pricing + Spot (~4 min, LIVE or pre-captured)

**The story:** Manager asks "what will this cost — and what if we use Spot?"

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

**Part B — Spot vs. On-Demand:**

```powershell
.\Get-AzVMAvailability.ps1 -Recommend "Standard_D4s_v5" -Region "eastus" -ShowPricing -ShowSpot -NoPrompt
```

**Part B talking points:**
- "`-ShowSpot` adds a Spot $/hr column in recommend mode alongside the regular on-demand price."
- "Typical spot discounts run 40-80% off on-demand. Great for batch jobs, rendering, and interruptible workloads."
- "You see both prices side-by-side so you can make the trade-off decision instantly."
- "`-ShowSpot` is available in recommend mode when `-ShowPricing` is also enabled."

**Transition:**
> "Cost and capacity are covered. But have you ever deployed a VM and *then* found out your image doesn't support that SKU? Gen1 vs Gen2, x64 vs ARM64..."

---

### Scenario 6: Image Compatibility (~3 min, LIVE)

**The story:** Customer wants to deploy Ubuntu ARM64 — which SKUs actually support it?

```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus" -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest" -EnableDrillDown -NoPrompt
```

**Talking points:**
- "`-ImageURN` specifies a VM image using the standard Publisher:Offer:Sku:Version format."
- "The tool detects that this Ubuntu image is ARM64 and Gen2 — then flags every SKU that can't run it."
- "You'll see Gen and Arch columns in the drill-down (same feature from Scenario 1), plus an `Img` compatibility indicator."
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

### Scenario 7: Recommend Mode — The Money Scenario (~5 min, LIVE)

**The story:** Customer calls: "My Standard_D4s_v3 is capacity constrained in East US. What do I do?"

> **5S:** Story (support call everyone has gotten), Surprise (scored ranking they didn't expect), Salient (100-point rubric, ranked in 30 seconds), Symbol (Score column), Slogan below
> **Slogan:** *"Stop guessing. Get a ranked list of alternatives in 30 seconds."*

> **Presenter note — Near Miss:** Before running the tool, show the *almost-right* answer — the thing people do today. This contrast is what locks the value in permanently.
>
> The near miss: a customer submits `az vm create --size Standard_D4s_v3` and gets back `AllocationFailed: Requested operation cannot be performed because SKU 'Standard_D4s_v3' is not available for requested region East US`. They guess `D4s_v4`. Also constrained. They try `D4s_v5`. Available — but is it the right fit? Is it cheaper or more expensive? Will it run their software? They don't know. They're guessing.
>
> *That* is the near miss. Everything they tried was almost right. Now show what right actually looks like.

```powershell
.\Get-AzVMAvailability.ps1 -Recommend "Standard_D4s_v3" -Region "eastus","westus2" -ShowPricing -TopN 10 -NoPrompt
```

**Talking points:**
- "This is the scenario that saves the most time. Customer gives you a SKU name, you paste it in, and get a ranked list of alternatives in 30 seconds."
- "The scoring algorithm weighs 6 dimensions: vCPU count (25 points), memory (25), family match (20), VM generation (13), CPU architecture (12), and premium IO support (5). Max score is 100."
- "A score of 95-100 means it's nearly identical. 80-90 means same family, slightly different specs. Below 70, you're crossing into different families."
- "Adding `-ShowPricing` lets you immediately see if the alternative is cheaper or more expensive."
- "v1.10 added CPU (Intel/AMD/ARM) and Disk columns so you see the full hardware profile without leaving the tool."
- "We're scanning two regions here — so you can also tell the customer 'Your SKU is constrained in East US but has full capacity in West US 2.'"

**What to highlight on screen:**
- The similarity scores in the Score column
- The target SKU profile at the top (vCPU, memory, family)
- The CPU and Disk columns showing hardware details per alternative
- Alternatives ranked by score with pricing comparison
- Capacity status of each alternative in each region

**Part B — ARM64 candidates with fleet safety:**

```powershell
.\Get-AzVMAvailability.ps1 -Recommend "Standard_D4s_v3" -Region "eastus" -AllowMixedArch -ShowPricing -TopN 10 -NoPrompt
```

**Part B talking points:**
- "By default, the recommender filters to the same CPU architecture as the target — so x64 targets only see x64 alternatives."
- "`-AllowMixedArch` opens it up to include ARM64 Ampere SKUs — often lower price, but a code recompile is needed."
- "When mixed architectures appear together, fleet safety warnings fire automatically to prevent accidental x64/ARM64 fleet mixing."

**Transition:**
> "Everything we've seen outputs to the terminal. But what about automation pipelines and executive reports?"

---

## RUN — "Automation & Export"

### Scenario 8: JSON + Excel Export (~3 min, LIVE or pre-captured)

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

### Contribution Statement (say this — don't recap)

> **Presenter note:** Winston's rule: end with a contribution, not a summary. Don't tell them what you showed them. Tell them what they now *have* that they didn't have when they walked in.

> "An hour ago, if a customer called and said 'I need a D4s_v5 in East US' — you'd open the portal, click through five blades, maybe call support, and still not know if the allocation would succeed."
>
> "Right now, you can answer that call in 30 seconds. You know which regions have capacity, which alternatives score closest to what they need, what those alternatives cost, whether their image is compatible, and how likely Azure is to actually fulfill the request — all before you deploy a single resource."
>
> "That's not a nice-to-have. That's the difference between a 40-minute support call and a 30-second answer."

---

### Reference: What We Covered

| Capability | How |
|---|---|
| Interactive exploration | Just run the script, no parameters |
| Drill-down | `-EnableDrillDown` for per-SKU Gen/Arch/CPU/Disk/zone detail |
| Multi-region comparison | `-Region` with multiple values or `-RegionPreset` |
| Family filtering | `-FamilyFilter "D","E"` |
| Placement scores | `-ShowPlacement` (allocation likelihood: High/Medium/Low) |
| Live pricing | `-ShowPricing` (auto-detects EA/retail) |
| Spot vs. on-demand | `-Recommend "SKU" -ShowPricing -ShowSpot` (recommend mode; side-by-side cost delta) |
| Image compatibility | `-ImageURN` with drill-down |
| SKU recommendations | `-Recommend "SKU_Name"` with scoring |
| Arch filtering | `-AllowMixedArch` for ARM64 candidates + fleet safety |
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
| "What's the placement score for a SKU?" | Use `-ShowPlacement`. Requires Compute Recommendations RBAC role. |
| "Can I see Spot prices?" | Use `-Recommend "SKU" -ShowPricing -ShowSpot` — Spot pricing is available in recommend mode when `-ShowPricing` is also enabled. |
| "Can I include ARM64 alternatives?" | Use `-AllowMixedArch` with `-Recommend`. Fleet safety warnings fire when mixed arch appears. |

### Project Links

- **Repository:** [github.com/zacharyluz/Get-AzVMAvailability](https://github.com/zacharyluz/Get-AzVMAvailability)
- **Issues / Feature Requests:** via GitHub Issues
- **License:** MIT

---

## Appendix: Pre-Captured Output Tips

For scenarios that take longer (pricing lookups, large region scans), consider preparing screenshots or terminal recordings:

1. **Pricing (Scenario 5):** First pricing call can take 5-10 seconds while the Retail API responds. Run once before the demo to warm up your session.
2. **Excel (Scenario 8B):** Have a pre-generated XLSX file open in Excel as a backup. The conditional formatting is the showpiece.
3. **Image drill-down (Scenario 6):** If your subscription has restricted SKUs, the contrast between compatible and incompatible rows is more dramatic — pick a subscription where you'll see both.
4. **Placement Scores (Scenario 4):** Requires "Compute Recommendations" RBAC role. If the role isn't assigned, test in a subscription where it is, or note that it degrades gracefully.

### Recommended Demo Order Adjustments

- **Short version (15 min):** Scenarios 1, 2, 7, 8A — skip presets, pricing, and image compat.
- **Executive version (10 min):** Scenarios 2, 7, 8B — targeted results, recommendations, Excel handoff.
- **Engineer version (20 min):** Scenarios 1, 2, 4, 5, 6, 7 — skip JSON/Excel automation.
- **Full feature version (40 min):** All 8 scenarios — show the complete crawl/walk/run arc.
