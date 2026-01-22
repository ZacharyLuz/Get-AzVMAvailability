# Roadmap

## Version 1.0.0 (Current Release)
- ✅ Multi-region parallel scanning
- ✅ SKU availability and capacity status
- ✅ Zone-level restriction details
- ✅ Quota tracking per family
- ✅ Multi-region comparison matrix
- ✅ Interactive drill-down
- ✅ CSV/XLSX export with conditional formatting
- ✅ Unicode/ASCII icon auto-detection

---

## Version 1.1.0 (Planned)
**Theme: Azure Resource Graph Integration**

### New Features
- [ ] **Current VM Inventory** - Show existing VMs deployed per region/SKU family
- [ ] **Cross-Subscription Discovery** - Use ARG to discover all accessible subscriptions faster
- [ ] **Deployment Density** - Visualize how many VMs are already in each region
- [ ] **Compare Available vs Deployed** - Side-by-side view of capacity vs current usage

### Technical Implementation
```powershell
# Example ARG query for VM inventory
$query = @"
Resources
| where type =~ 'Microsoft.Compute/virtualMachines'
| extend vmSize = properties.hardwareProfile.vmSize
| extend vmFamily = extract('Standard_([A-Z]+)', 1, tostring(vmSize))
| summarize VMCount = count() by subscriptionId, location, vmFamily
| order by VMCount desc
"@
Search-AzGraph -Query $query -First 1000
```

### New Parameters
- `-IncludeInventory` - Include current VM deployment data
- `-AllSubscriptions` - Scan all accessible subscriptions via ARG

---

## Version 1.2.0 (Planned)
**Theme: Enhanced Reporting**

- [ ] **HTML Report Export** - Self-contained HTML report with charts
- [ ] **Trend Tracking** - Compare against previous scan results
- [ ] **Email Report** - Send results via email (optional)
- [ ] **Slack/Teams Webhook** - Post summary to chat channels

---

## Version 2.0.0 (Future)
**Theme: Proactive Monitoring**

- [ ] **Watch Mode** - Continuous monitoring with alerts
- [ ] **Capacity Alerts** - Notify when capacity status changes
- [ ] **Azure Monitor Integration** - Log results to Log Analytics
- [ ] **Azure Function Deployment** - Run as scheduled serverless function
- [ ] **REST API Wrapper** - Expose as lightweight API

---

## Contributing

Have ideas for new features? Open an issue or submit a PR!

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
