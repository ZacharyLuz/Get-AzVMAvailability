Install-Module -Name Az.Compute -Scope CurrentUser -Repository PSGallery -Force
Install-Module -Name Az.Resources -Scope CurrentUser -Repository PSGallery -Force
Install-Module -Name ImportExcel -Scope CurrentUser
New-Item -ItemType Directory -Path . -Force
Register-PSRepository -Name Get-AzVMAvailability -SourceLocation . -InstallationPolicy Trusted