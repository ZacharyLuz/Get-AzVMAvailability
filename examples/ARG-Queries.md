# Azure Resource Graph Queries for VM Capacity Planning

These queries complement the Azure VM Capacity Checker by providing deployment context.
They help answer "what do I have deployed?" while the main script answers "what can I deploy?"

## Prerequisites

```powershell
# Install Az.ResourceGraph module if needed
Install-Module -Name Az.ResourceGraph -Scope CurrentUser

# Connect to Azure
Connect-AzAccount
```

---

## Query 1: Current VM Inventory by Region and Family

Shows what VMs you have deployed, grouped by region and SKU family.

```powershell
$query = @"
Resources
| where type =~ 'Microsoft.Compute/virtualMachines'
| extend vmSize = tostring(properties.hardwareProfile.vmSize)
| extend vmFamily = extract('Standard_([A-Z]+)', 1, vmSize)
| summarize VMCount = count(), TotalvCPUs = sum(toint(extract('\\d+', 0, vmSize))) by location, vmFamily
| order by location asc, VMCount desc
"@

Search-AzGraph -Query $query -First 1000 | Format-Table -AutoSize
```

**Output:**
```
location    vmFamily VMCount TotalvCPUs
--------    -------- ------- ----------
eastus      D        45      180
eastus      E        12      96
eastus2     D        30      120
westus2     F        8       32
```

---

## Query 2: VM Count by SKU Size (Detailed)

Shows exact SKU sizes in use across all subscriptions.

```powershell
$query = @"
Resources
| where type =~ 'Microsoft.Compute/virtualMachines'
| extend vmSize = tostring(properties.hardwareProfile.vmSize)
| summarize Count = count() by vmSize, location
| order by Count desc
"@

Search-AzGraph -Query $query -First 500
```

---

## Query 3: Cross-Subscription VM Distribution

See VM distribution across all accessible subscriptions.

```powershell
$query = @"
Resources
| where type =~ 'Microsoft.Compute/virtualMachines'
| extend vmSize = tostring(properties.hardwareProfile.vmSize)
| extend vmFamily = extract('Standard_([A-Z]+)', 1, vmSize)
| summarize VMCount = count() by subscriptionId, location, vmFamily
| join kind=leftouter (
    ResourceContainers
    | where type =~ 'microsoft.resources/subscriptions'
    | project subscriptionId, subscriptionName = name
) on subscriptionId
| project subscriptionName, location, vmFamily, VMCount
| order by subscriptionName, location, VMCount desc
"@

Search-AzGraph -Query $query -First 1000
```

---

## Query 4: Find VMs Using Constrained SKUs

Identify VMs using SKUs that might be at risk during scaling.

```powershell
# First, get the constrained SKUs from our Capacity Checker
# Then query ARG for VMs using those SKUs

$constrainedSkus = @('Standard_NC6', 'Standard_NC12', 'Standard_NV6')  # Example

$skuFilter = ($constrainedSkus | ForEach-Object { "'$_'" }) -join ', '

$query = @"
Resources
| where type =~ 'Microsoft.Compute/virtualMachines'
| extend vmSize = tostring(properties.hardwareProfile.vmSize)
| where vmSize in ($skuFilter)
| project name, resourceGroup, location, vmSize, subscriptionId
| order by location, vmSize
"@

Search-AzGraph -Query $query
```

---

## Query 5: Availability Zone Distribution

See how your VMs are distributed across availability zones.

```powershell
$query = @"
Resources
| where type =~ 'Microsoft.Compute/virtualMachines'
| extend zone = tostring(zones[0])
| extend vmFamily = extract('Standard_([A-Z]+)', 1, tostring(properties.hardwareProfile.vmSize))
| summarize Count = count() by location, zone, vmFamily
| order by location, zone
"@

Search-AzGraph -Query $query
```

---

## Query 6: Regional VM Density Map

Visualize which regions have the most VM deployments.

```powershell
$query = @"
Resources
| where type =~ 'Microsoft.Compute/virtualMachines'
| summarize VMCount = count() by location
| order by VMCount desc
"@

$results = Search-AzGraph -Query $query

# Display as a simple bar chart
$results | ForEach-Object {
    $bar = '█' * [math]::Min([math]::Ceiling($_.VMCount / 5), 50)
    "{0,-20} {1,5} {2}" -f $_.location, $_.VMCount, $bar
}
```

---

## Combining ARG with Capacity Checker

For a complete picture, use both tools:

```powershell
# Step 1: Get current deployment density from ARG
$deployed = Search-AzGraph -Query @"
Resources
| where type =~ 'Microsoft.Compute/virtualMachines'
| extend vmFamily = extract('Standard_([A-Z]+)', 1, tostring(properties.hardwareProfile.vmSize))
| summarize Deployed = count() by location, vmFamily
"@

# Step 2: Run Capacity Checker to get availability
.\Azure-VM-Capacity-Checker.ps1 -NoPrompt -Region "eastus","westus2" -AutoExport

# Step 3: Compare deployed vs available capacity
# (Future v1.1 feature will automate this!)
```

---

## Why These Queries Are Useful

| Use Case                                  | ARG Query | Capacity Checker |
| ----------------------------------------- | --------- | ---------------- |
| "Where are my VMs?"                       | ✅         | ❌                |
| "What can I deploy?"                      | ❌         | ✅                |
| "Is this SKU restricted?"                 | ❌         | ✅                |
| "How many D-series VMs do I have?"        | ✅         | ❌                |
| "Which region has capacity for E-series?" | ❌         | ✅                |
| "Am I over-concentrated in one region?"   | ✅         | ❌                |

**Best Practice:** Use ARG for inventory analysis, use Capacity Checker for deployment planning.
