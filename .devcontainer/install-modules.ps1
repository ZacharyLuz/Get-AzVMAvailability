Install-Module -Name Az.Compute -Scope CurrentUser -Repository PSGallery -Force
Install-Module -Name Az.Resources -Scope CurrentUser -Repository PSGallery -Force
Install-Module -Name ImportExcel -Scope CurrentUser -Repository PSGallery -Force
# Register local repository for the Get-AzVMAvailability project if it does not already exist
if (-not (Get-PSRepository -Name 'Get-AzVMAvailability' -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Name Get-AzVMAvailability -SourceLocation . -InstallationPolicy Trusted
}