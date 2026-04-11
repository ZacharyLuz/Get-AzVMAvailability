# Using GitHub Codespaces

[← Back to README](../README.md)

A pre-configured codespace that automatically installs the required modules when first created has been defined in the `.devcontainer` folder of this repo. This means no downloading or installing of any code on your local machine. Simply follow these steps:

- In GitHub, select the **Codespaces** tab from the **Code** dropdown in GitHub on the Repo's (or your fork's) main page.
- Click on the plus (+) icon to create a new codespace
- Wait for the codespace to finish installing/creating
- Run the following commands

```powershell
# Use this instead if calling from a codespace
Connect-AzAccount -Tenant YourTenantIdHere -subscription YourSubIdHere -UseDeviceAuthentication

# Interactive mode - prompts for all options
.\Get-AzVMAvailability.ps1

# See further in this document for other examples outside of interactive mode
```
