# Supported Cloud Environments

[← Back to README](../README.md)

The script automatically detects your Azure environment and uses the correct API endpoints:

| Cloud            | Environment Name    | Status              |
| ---------------- | ------------------- | ------------------- |
| Azure Commercial | `AzureCloud`        | ✅ Supported         |
| Azure Government | `AzureUSGovernment` | ✅ Supported         |
| Azure China      | `AzureChinaCloud`   | ✅ Supported         |
| Azure Germany    | `AzureGermanCloud`  | ⚠️ Deprecated/legacy |

**No configuration required** - the script reads your current `Az` context and resolves endpoints automatically.
