# Supported Cloud Environments

[← Back to README](../README.md)

The script automatically detects your Azure environment and uses the correct API endpoints:

| Cloud            | Environment Name    | Supported |
| ---------------- | ------------------- | --------- |
| Azure Commercial | `AzureCloud`        | ✅         |
| Azure Government | `AzureUSGovernment` | ✅         |
| Azure China      | `AzureChinaCloud`   | ✅         |
| Azure Germany    | `AzureGermanCloud`  | ✅         |

**No configuration required** - the script reads your current `Az` context and resolves endpoints automatically.
