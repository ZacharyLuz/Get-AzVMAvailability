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
    $publicFile = Join-Path $PSScriptRoot '..' 'AzVMAvailability' 'Public' 'Get-AzVMAvailability.ps1'
    if (-not (Test-Path -LiteralPath $publicFile)) {
        throw "Public function file not found: $publicFile"
    }
    $publicFile = (Resolve-Path -LiteralPath $publicFile).Path

    $parseErrors = $null
    $parsedTokens = $null
    $publicAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $publicFile, [ref]$parsedTokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $messages = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
        throw "Public file failed to parse: $publicFile :: $messages"
    }

    # Find every hashtable in the public file that contains an 'SKUs_OK' key.
    # In the correct file there is exactly one such site (the per-family
    # $exportRow construction); finding more or fewer indicates a structural
    # change worth a manual review.
    $skusOkHashtables = $publicAst.FindAll(
        {
            param($node)
            ($node -is [System.Management.Automation.Language.HashtableAst]) -and
            (@($node.KeyValuePairs | Where-Object {
                $_.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                $_.Item1.Value -eq 'SKUs_OK'
            }).Count -gt 0)
        },
        $true
    )

    $script:SkusOkHashtableCount = @($skusOkHashtables).Count

    if ($script:SkusOkHashtableCount -eq 1) {
        $kvp = $skusOkHashtables[0].KeyValuePairs | Where-Object {
            $_.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $_.Item1.Value -eq 'SKUs_OK'
        } | Select-Object -First 1
        $script:SkusOkExprText = $kvp.Item2.Extent.Text
        # Wrap with an explicit param so $stats is a declared input (avoids
        # PSUseDeclaredVarsMoreThanAssignments warnings in callers) and makes
        # the contract of the extracted expression visible. The newline
        # between the param block and the extracted text ensures they parse
        # as separate statements even if the extracted text ever starts with
        # a leading comment or statement separator.
        $script:SkusOkScript = [scriptblock]::Create("param(`$stats)`n$($script:SkusOkExprText)")
    }
    else {
        # Either 0 sites (AST extraction failed) or 2+ sites (structural
        # change in the public file). In both cases we cannot safely pick
        # a single site to evaluate; leave the extracted artifacts null and
        # let the AST-extraction count assertion + the runtime-context guard
        # fail with their explicit messages.
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
            $script:SkusOkExprText | Should -Match '\bRestrictionStatus\b'
        }

        It "Extracted value expression references Measure-Object summing Available" {
            $script:SkusOkExprText | Should -Match '\bMeasure-Object\b'
            $script:SkusOkExprText | Should -Match '\bAvailable\b'
        }

        It "Extracted value expression does not contain a nested function definition (corruption signature)" {
            $script:SkusOkExprText | Should -Not -Match 'function\s+Get-AzVMAvailability'
        }
    }

    Context "Runtime evaluation against mock per-region stats" {

        BeforeAll {
            # Guard: if AST extraction in the outer BeforeAll failed, fail this
            # context fast with an actionable message instead of letting each It
            # block produce a confusing 'cannot invoke null scriptblock' error.
            if ($null -eq $script:SkusOkScript) {
                throw "Runtime tests cannot run: SKUs_OK expression was not extracted from the public file. See AST extraction failures above."
            }
        }

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

        It "Returns 0 or null when no region has RestrictionStatus OK (Measure-Object empty-pipeline semantics; PS-version-tolerant)" {
            $stats = [PSCustomObject]@{
                Regions = @{
                    'eastus'  = [PSCustomObject]@{ RestrictionStatus = 'LIMITED';      Available = 1; Count = 1 }
                    'westus2' = [PSCustomObject]@{ RestrictionStatus = 'ZONE-LIMITED'; Available = 4; Count = 4 }
                }
            }
            $result = & $script:SkusOkScript -stats $stats
            # Measure-Object on an empty filtered pipeline emits a Measurement
            # object whose .Sum is $null on current PowerShell versions; allow
            # 0 too in case that ever changes (per PR #171 review feedback).
            $result | Should -BeIn @($null, 0)
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
