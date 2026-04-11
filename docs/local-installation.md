# Local Installation

[← Back to README](../README.md)

```powershell
# Clone the repository
git clone https://github.com/zacharyluz/Get-AzVMAvailability.git
cd Get-AzVMAvailability

# Install required Azure modules (if needed)
# Windows only: enable running scripts from the PowerShell Gallery in your profile
if ($IsWindows) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
}
Install-Module -Name Az.Accounts -Scope CurrentUser -Repository PSGallery -Force
Install-Module -Name Az.Compute -Scope CurrentUser -Repository PSGallery -Force
Install-Module -Name Az.Resources -Scope CurrentUser -Repository PSGallery -Force

# Optional: Install ImportExcel for styled exports
Install-Module -Name ImportExcel -Scope CurrentUser -Repository PSGallery -Force

# Import the module directly from the repo
Import-Module .\AzVMAvailability
```
