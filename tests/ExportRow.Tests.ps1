# ExportRow.Tests.ps1
# Pester regression tests for the per-family $exportRow construction inside
# Get-AzVMAvailability (issue #170).
#
# The bug: the SKUs_OK value expression inside the per-family $exportRow hashtable
# - a Where-Object pipeline over $stats.Regions.Values - was malformed in v3.0.0,
# causing the export pipeline to crash at runtime with
# "'.RestrictionStatus' is not recognized as a name of a cmdlet".
#
# These tests extract the actual SKUs_OK value expression from the production
# module file via AST, then execute it against a mock $stats input and assert
# that it returns the correct OK-count. A regression of the v3.0.0 corruption
# would either fail the AST extraction or fail at runtime - either way the
# test fails.
#
# Run with: Invoke-Pester ./tests/ExportRow.Tests.ps1 -Output Detailed

BeforeAll {
    $publicFile = Join-Path $PSScriptRoot '..' 'AzVMAvailability' 'Public' 'Get-AzVMAvailability.ps1' | Resolve-Path
    if (-not (Test-Path $publicFile)) {
        throw "Public function file not found: $publicFile"
    }

    $parseErrors = $null
    $parsedTokens = $null
    $publicAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $publicFile, [ref]$parsedTokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $messages = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
        throw "Public file failed to parse: $messages"
    }

    # Find every hashtable in the public file that contains an 'SKUs_OK' key.
    # In the correct file there is exactly one such site (the per-family
    # $exportRow construction); finding more or fewer indicates a structural
    # change worth a manual review.
    $skusOkHashtables = $publicAst.FindAll(
        {
            param($node)
            ($node -is [System.Management.Automation.Language.HashtableAst]) -and
            ($node.KeyValuePairs | Where-Object { $_.Item1.Value -eq 'SKUs_OK' })
        },
        $true
    )

    $script:SkusOkHashtableCount = @($skusOkHashtables).Count

    if ($script:SkusOkHashtableCount -ge 1) {
        $kvp = $skusOkHashtables[0].KeyValuePairs | Where-Object { $_.Item1.Value -eq 'SKUs_OK' } | Select-Object -First 1
        $script:SkusOkExprText = $kvp.Item2.Extent.Text
        # Wrap with an explicit param so $stats is a declared input (avoids
        # PSUseDeclaredVarsMoreThanAssignments warnings in callers) and makes
        # the contract of the extracted expression visible.
        $script:SkusOkScript = [scriptblock]::Create("param(`$stats) $($script:SkusOkExprText)")
    }
    else {
        $script:SkusOkExprText = $null
        $script:SkusOkScript = $null
    }
}

Describe "Per-family exportRow SKUs_OK expression (regression for #170)" {

    Context "AST extraction" {

        It "Finds exactly one SKUs_OK hashtable site in the public function" {
            $script:SkusOkHashtableCount | Should -Be 1
        }

        It "Extracted value expression references RestrictionStatus" {
            $script:SkusOkExprText | Should -Not -BeNullOrEmpty
            $script:SkusOkExprText | Should -Match 'RestrictionStatus'
        }

        It "Extracted value expression references Measure-Object summing Available" {
            $script:SkusOkExprText | Should -Match 'Measure-Object'
            $script:SkusOkExprText | Should -Match 'Available'
        }

        It "Extracted value expression does not contain a nested function definition (corruption signature)" {
            $script:SkusOkExprText | Should -Not -Match 'function\s+Get-AzVMAvailability'
        }
    }

    Context "Runtime evaluation against mock per-region stats" {

        It "Returns the sum of Available across regions whose RestrictionStatus is OK" {
            $stats = [PSCustomObject]@{
                Regions = @{
                    'eastus'  = [PSCustomObject]@{ RestrictionStatus = 'OK';      Available = 3; Count = 5 }
                    'westus2' = [PSCustomObject]@{ RestrictionStatus = 'LIMITED'; Available = 7; Count = 7 }
                    'westeu'  = [PSCustomObject]@{ RestrictionStatus = 'OK';      Available = 2; Count = 2 }
                }
            }
            $result = & $script:SkusOkScript -stats $stats
            $result | Should -Be 5
        }

        It "Returns null when no region has RestrictionStatus OK (Measure-Object empty-pipeline semantics)" {
            $stats = [PSCustomObject]@{
                Regions = @{
                    'eastus'  = [PSCustomObject]@{ RestrictionStatus = 'LIMITED';      Available = 1; Count = 1 }
                    'westus2' = [PSCustomObject]@{ RestrictionStatus = 'ZONE-LIMITED'; Available = 4; Count = 4 }
                }
            }
            $result = & $script:SkusOkScript -stats $stats
            $result | Should -BeNullOrEmpty
        }

        It "Does not throw when given a well-formed stats input (issue #170 reproduction check)" {
            $stats = [PSCustomObject]@{
                Regions = @{
                    'eastus' = [PSCustomObject]@{ RestrictionStatus = 'OK'; Available = 1; Count = 1 }
                }
            }
            { & $script:SkusOkScript -stats $stats } | Should -Not -Throw
        }
    }
}
