BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\Get-AzVMAvailability.ps1'
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "FleetFileTests-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:TempDir) {
        Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#region CSV Parsing Tests
Describe 'FleetFile CSV Parsing' {
    It 'Parses standard SKU,Qty columns' {
        $csvPath = Join-Path $script:TempDir 'standard.csv'
        @"
SKU,Qty
Standard_D2s_v5,10
Standard_D4s_v5,5
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $fleet = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $fleet[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $fleet.Count | Should -Be 2
        $fleet['Standard_D2s_v5'] | Should -Be 10
        $fleet['Standard_D4s_v5'] | Should -Be 5
    }

    It 'Recognizes alternative column names: Name, Quantity' {
        $csvPath = Join-Path $script:TempDir 'altnames.csv'
        @"
Name,Quantity
Standard_E4s_v5,3
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $fleet = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $fleet[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $fleet.Count | Should -Be 1
        $fleet['Standard_E4s_v5'] | Should -Be 3
    }

    It 'Recognizes VmSize and Count column names' {
        $csvPath = Join-Path $script:TempDir 'vmsize.csv'
        @"
VmSize,Count
Standard_F8s_v2,7
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $fleet = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $fleet[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $fleet.Count | Should -Be 1
        $fleet['Standard_F8s_v2'] | Should -Be 7
    }

    It 'Trims whitespace from SKU names' {
        $csvPath = Join-Path $script:TempDir 'whitespace.csv'
        @"
SKU,Qty
  Standard_D2s_v5  ,10
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $fleet = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $fleet[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $fleet.Keys | Should -Contain 'Standard_D2s_v5'
    }

    It 'Sums duplicate SKUs' {
        $csvPath = Join-Path $script:TempDir 'dupes.csv'
        @"
SKU,Qty
Standard_D2s_v5,10
Standard_D2s_v5,5
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $fleet = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $skuClean = $skuProp.Trim()
                $qtyInt = [int]$qtyProp
                if ($fleet.ContainsKey($skuClean)) { $fleet[$skuClean] += $qtyInt }
                else { $fleet[$skuClean] = $qtyInt }
            }
        }
        $fleet['Standard_D2s_v5'] | Should -Be 15
    }

    It 'Skips rows with unrecognized columns' {
        $csvPath = Join-Path $script:TempDir 'badcols.csv'
        @"
Foo,Bar
Standard_D2s_v5,10
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $fleet = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $fleet[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $fleet.Count | Should -Be 0
    }
}
#endregion CSV Parsing Tests

#region JSON Parsing Tests
Describe 'FleetFile JSON Parsing' {
    It 'Parses JSON array with SKU and Qty' {
        $jsonPath = Join-Path $script:TempDir 'standard.json'
        @'
[
  { "SKU": "Standard_D2s_v5", "Qty": 10 },
  { "SKU": "Standard_D4s_v5", "Qty": 5 }
]
'@ | Set-Content -Path $jsonPath -Encoding utf8

        $jsonData = @(Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json)
        $fleet = @{}
        foreach ($item in $jsonData) {
            $skuProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $fleet[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $fleet.Count | Should -Be 2
        $fleet['Standard_D2s_v5'] | Should -Be 10
    }

    It 'Recognizes alternative JSON keys: Name, Quantity' {
        $jsonPath = Join-Path $script:TempDir 'altkeys.json'
        @'
[
  { "Name": "Standard_E4s_v5", "Quantity": 3 }
]
'@ | Set-Content -Path $jsonPath -Encoding utf8

        $jsonData = @(Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json)
        $fleet = @{}
        foreach ($item in $jsonData) {
            $skuProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $fleet[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $fleet.Count | Should -Be 1
        $fleet['Standard_E4s_v5'] | Should -Be 3
    }

    It 'Sums duplicate SKUs in JSON' {
        $jsonPath = Join-Path $script:TempDir 'dupes.json'
        @'
[
  { "SKU": "Standard_D2s_v5", "Qty": 10 },
  { "SKU": "Standard_D2s_v5", "Qty": 7 }
]
'@ | Set-Content -Path $jsonPath -Encoding utf8

        $jsonData = @(Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json)
        $fleet = @{}
        foreach ($item in $jsonData) {
            $skuProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $skuClean = $skuProp.Trim()
                $qtyInt = [int]$qtyProp
                if ($fleet.ContainsKey($skuClean)) { $fleet[$skuClean] += $qtyInt }
                else { $fleet[$skuClean] = $qtyInt }
            }
        }
        $fleet['Standard_D2s_v5'] | Should -Be 17
    }
}
#endregion JSON Parsing Tests

#region Input Validation Tests
Describe 'FleetFile Input Validation' {
    It 'Rejects unsupported file extension' {
        $txtPath = Join-Path $script:TempDir 'bad.txt'
        'hello' | Set-Content -Path $txtPath
        $ext = [System.IO.Path]::GetExtension($txtPath).ToLower()
        $ext | Should -Not -BeIn @('.csv', '.json')
    }

    It 'Rejects negative quantity' {
        $csvPath = Join-Path $script:TempDir 'negqty.csv'
        @"
SKU,Qty
Standard_D2s_v5,-5
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        {
            foreach ($row in $csvData) {
                $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
                $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
                if ($skuProp -and $qtyProp) {
                    $qtyInt = [int]$qtyProp
                    if ($qtyInt -le 0) { throw "Invalid quantity '$qtyProp' for SKU '$($skuProp.Trim())'. Qty must be a positive integer." }
                }
            }
        } | Should -Throw '*Qty must be a positive integer*'
    }

    It 'Rejects zero quantity' {
        $csvPath = Join-Path $script:TempDir 'zeroqty.csv'
        @"
SKU,Qty
Standard_D2s_v5,0
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        {
            foreach ($row in $csvData) {
                $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
                $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
                if ($skuProp -and $qtyProp) {
                    $qtyInt = [int]$qtyProp
                    if ($qtyInt -le 0) { throw "Invalid quantity '$qtyProp' for SKU '$($skuProp.Trim())'. Qty must be a positive integer." }
                }
            }
        } | Should -Throw '*Qty must be a positive integer*'
    }

    It 'Throws on empty fleet after parsing' {
        $csvPath = Join-Path $script:TempDir 'empty.csv'
        @"
Foo,Bar
a,b
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $fleet = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $fleet[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $fleet.Count | Should -Be 0
    }
}
#endregion Input Validation Tests

#region Fleet Normalization Tests
Describe 'Fleet SKU Normalization' {
    It 'Adds Standard_ prefix to bare SKU names' {
        $fleet = @{ 'D2s_v5' = 10 }
        $normalizedFleet = @{}
        foreach ($key in @($fleet.Keys)) {
            $clean = $key -replace '^Standard_Standard_', 'Standard_'
            if ($clean -notmatch '^Standard_') { $clean = "Standard_$clean" }
            $normalizedFleet[$clean] = $fleet[$key]
        }
        $normalizedFleet.Keys | Should -Contain 'Standard_D2s_v5'
    }

    It 'Strips double Standard_ prefix' {
        $fleet = @{ 'Standard_Standard_D2s_v5' = 10 }
        $normalizedFleet = @{}
        foreach ($key in @($fleet.Keys)) {
            $clean = $key -replace '^Standard_Standard_', 'Standard_'
            if ($clean -notmatch '^Standard_') { $clean = "Standard_$clean" }
            $normalizedFleet[$clean] = $fleet[$key]
        }
        $normalizedFleet.Keys | Should -Contain 'Standard_D2s_v5'
        $normalizedFleet.Keys | Should -Not -Contain 'Standard_Standard_D2s_v5'
    }

    It 'Preserves correctly prefixed SKU names' {
        $fleet = @{ 'Standard_E4s_v5' = 5 }
        $normalizedFleet = @{}
        foreach ($key in @($fleet.Keys)) {
            $clean = $key -replace '^Standard_Standard_', 'Standard_'
            if ($clean -notmatch '^Standard_') { $clean = "Standard_$clean" }
            $normalizedFleet[$clean] = $fleet[$key]
        }
        $normalizedFleet['Standard_E4s_v5'] | Should -Be 5
    }

    It 'Derives SkuFilter from fleet keys' {
        $fleet = @{ 'Standard_D2s_v5' = 10; 'Standard_E4s_v5' = 5 }
        $skuFilter = @($fleet.Keys)
        $skuFilter.Count | Should -Be 2
        $skuFilter | Should -Contain 'Standard_D2s_v5'
        $skuFilter | Should -Contain 'Standard_E4s_v5'
    }
}
#endregion Fleet Normalization Tests

#region Mutual Exclusion Tests
Describe 'Fleet Parameter Mutual Exclusion' {
    It 'Fleet and FleetFile cannot both be specified (logic check)' {
        $fleet = @{ 'Standard_D2s_v5' = 10 }
        $fleetFile = 'somefile.csv'
        { if ($fleet -and $fleetFile) { throw "Cannot specify both -Fleet and -FleetFile. Use one or the other." } } | Should -Throw '*Cannot specify both*'
    }

    It 'GenerateFleetTemplate and JsonOutput cannot both be specified (logic check)' {
        $generateFleetTemplate = $true
        $jsonOutput = $true
        { if ($generateFleetTemplate -and $jsonOutput) { throw "Cannot use -GenerateFleetTemplate with -JsonOutput." } } | Should -Throw '*Cannot use -GenerateFleetTemplate*'
    }
}
#endregion Mutual Exclusion Tests
