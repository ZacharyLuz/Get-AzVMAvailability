# AzVMAvailability Module Loader
# Dot-sources all private and public function files in dependency order

$ModuleRoot = $PSScriptRoot

# Module-scope console suppression flag — set per-invocation by Get-AzVMAvailability
$script:SuppressConsole = $false

# Write-Host override: gates console output when -JsonOutput is active.
# Removing this override will cause Write-Host output to leak into -JsonOutput stdout.
# Must be at module scope so all dot-sourced Private/ functions see it.
# Delegates to the original cmdlet via module-qualified name when not suppressed.
function Write-Host {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '',
        Justification = 'Intentional override to gate Write-Host output when -JsonOutput is active')]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$Object = '',
        [System.ConsoleColor]$ForegroundColor,
        [System.ConsoleColor]$BackgroundColor,
        [switch]$NoNewline
    )
    process {
        if ($script:SuppressConsole) { return }
        Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
    }
}

# Private functions — dot-source in dependency order
$privateDirs = @(
    'Utility'     # Zero dependencies
    'SKU'         # Depends on Utility (Get-SafeString used by some)
    'Azure'       # Depends on Utility (Invoke-WithRetry used by API functions)
    'Image'       # Depends on SKU
    'Inventory'   # Depends on SKU, Utility
    'Format'      # Depends on SKU, Utility, Azure
)

foreach ($dir in $privateDirs) {
    $dirPath = Join-Path $ModuleRoot "Private\$dir"
    if (Test-Path $dirPath) {
        foreach ($file in (Get-ChildItem -Path $dirPath -Filter '*.ps1' -File)) {
            . $file.FullName
        }
    }
}

# Public functions
$publicPath = Join-Path $ModuleRoot 'Public'
if (Test-Path $publicPath) {
    foreach ($file in (Get-ChildItem -Path $publicPath -Filter '*.ps1' -File)) {
        . $file.FullName
    }
}
