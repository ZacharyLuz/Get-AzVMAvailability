# Supported Cloud Environments

[← Back to README](../README.md)

The script automatically detects your Azure environment and uses the correct API endpoints:

| Cloud            | Environment Name    | Status              |
| ---------------- | ------------------- | ------------------- |
| Azure Commercial | `AzureCloud`        | ✅ Supported         |
| Azure Government | `AzureUSGovernment` | ✅ Supported         |
| Azure China      | `AzureChinaCloud`   | ✅ Supported         |

**No configuration required** - the script reads your current `Az` context and resolves endpoints automatically.

## Smart Default Regions

When no `-Region` is specified, the tool automatically selects default regions appropriate for your cloud environment and location:

| Cloud / Location | Default Regions | Detection |
|------------------|----------------|----------|
| Azure Government | usgovvirginia, usgovtexas, usgovarizona | `(Get-AzContext).Environment.Name` |
| Azure China | chinaeast, chinaeast2, chinanorth | `(Get-AzContext).Environment.Name` |
| Commercial — Americas (UTC-10 to UTC-3) | eastus, eastus2, centralus | Local timezone |
| Commercial — Europe (UTC-2 to UTC+3) | westeurope, northeurope, uksouth | Local timezone |
| Commercial — India/ME (UTC+3.5 to UTC+6) | centralindia, uaenorth, westindia | Local timezone |
| Commercial — APAC (UTC+7 to UTC+9.5) | eastasia, southeastasia, japaneast | Local timezone |
| Commercial — Australia (UTC+10 to UTC+13) | australiaeast, australiasoutheast, eastasia | Local timezone |

Sovereign cloud detection always takes priority over timezone. This ensures users connected to Government or China tenants never default to commercial regions.
