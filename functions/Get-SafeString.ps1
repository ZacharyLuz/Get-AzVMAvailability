# Get-SafeString.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 640)
# Sanitizes a string for safe use in output by trimming and escaping
# DO NOT execute this file directly — it is a documentation reference only.
function Get-SafeString {
    <#
    .SYNOPSIS
        Safely converts a value to string, unwrapping arrays from parallel execution.
    .DESCRIPTION
        When using ForEach-Object -Parallel, PowerShell serializes objects which can
        wrap strings in arrays. This function recursively unwraps those arrays to
        get the underlying string value. Critical for hashtable key lookups.
    #>
    param([object]$Value)
    if ($null -eq $Value) { return '' }
    # Recursively unwrap nested arrays (parallel execution can create multiple levels)
    while ($Value -is [array] -and $Value.Count -gt 0) {
        $Value = $Value[0]
    }
    if ($null -eq $Value) { return '' }
    return "$Value"  # String interpolation is safer than .ToString()
}
