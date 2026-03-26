# AzVMAvailability Module Loader
# Dot-sources all private function files in dependency order

$ModuleRoot = $PSScriptRoot

# Private functions — dot-source in dependency order
$privateDirs = @(
    'Utility'   # Zero dependencies
    'SKU'       # Depends on Utility (Get-SafeString used by some)
    'Azure'     # Depends on Utility (Invoke-WithRetry used by API functions)
    'Image'     # Depends on SKU
    'Inventory'   # Depends on SKU, Utility
    'Format'    # Depends on SKU, Utility, Azure
)

foreach ($dir in $privateDirs) {
    $dirPath = Join-Path $ModuleRoot "Private\$dir"
    if (Test-Path $dirPath) {
        foreach ($file in (Get-ChildItem -Path $dirPath -Filter '*.ps1' -File)) {
            . $file.FullName
        }
    }
}
