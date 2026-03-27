BeforeAll {
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "InventoryFileTests-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:TempDir) {
        Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

#region CSV Parsing Tests
Describe 'InventoryFile CSV Parsing' {
    It 'Parses standard SKU,Qty columns' {
        $csvPath = Join-Path $script:TempDir 'standard.csv'
        @"
SKU,Qty
Standard_D2s_v5,10
Standard_D4s_v5,5
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $inventory = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $inventory[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $inventory.Count | Should -Be 2
        $inventory['Standard_D2s_v5'] | Should -Be 10
        $inventory['Standard_D4s_v5'] | Should -Be 5
    }

    It 'Recognizes alternative column names: Name, Quantity' {
        $csvPath = Join-Path $script:TempDir 'altnames.csv'
        @"
Name,Quantity
Standard_E4s_v5,3
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $inventory = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $inventory[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $inventory.Count | Should -Be 1
        $inventory['Standard_E4s_v5'] | Should -Be 3
    }

    It 'Recognizes VmSize and Count column names' {
        $csvPath = Join-Path $script:TempDir 'vmsize.csv'
        @"
VmSize,Count
Standard_F8s_v2,7
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $inventory = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $inventory[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $inventory.Count | Should -Be 1
        $inventory['Standard_F8s_v2'] | Should -Be 7
    }

    It 'Trims whitespace from SKU names' {
        $csvPath = Join-Path $script:TempDir 'whitespace.csv'
        @"
SKU,Qty
  Standard_D2s_v5  ,10
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $inventory = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $inventory[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $inventory.Keys | Should -Contain 'Standard_D2s_v5'
    }

    It 'Sums duplicate SKUs' {
        $csvPath = Join-Path $script:TempDir 'dupes.csv'
        @"
SKU,Qty
Standard_D2s_v5,10
Standard_D2s_v5,5
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $inventory = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $skuClean = $skuProp.Trim()
                $qtyInt = [int]$qtyProp
                if ($inventory.ContainsKey($skuClean)) { $inventory[$skuClean] += $qtyInt }
                else { $inventory[$skuClean] = $qtyInt }
            }
        }
        $inventory['Standard_D2s_v5'] | Should -Be 15
    }

    It 'Skips rows with unrecognized columns' {
        $csvPath = Join-Path $script:TempDir 'badcols.csv'
        @"
Foo,Bar
Standard_D2s_v5,10
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $inventory = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $inventory[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $inventory.Count | Should -Be 0
    }
}
#endregion CSV Parsing Tests

#region JSON Parsing Tests
Describe 'InventoryFile JSON Parsing' {
    It 'Parses JSON array with SKU and Qty' {
        $jsonPath = Join-Path $script:TempDir 'standard.json'
        @'
[
  { "SKU": "Standard_D2s_v5", "Qty": 10 },
  { "SKU": "Standard_D4s_v5", "Qty": 5 }
]
'@ | Set-Content -Path $jsonPath -Encoding utf8

        $jsonData = @(Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json)
        $inventory = @{}
        foreach ($item in $jsonData) {
            $skuProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $inventory[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $inventory.Count | Should -Be 2
        $inventory['Standard_D2s_v5'] | Should -Be 10
    }

    It 'Recognizes alternative JSON keys: Name, Quantity' {
        $jsonPath = Join-Path $script:TempDir 'altkeys.json'
        @'
[
  { "Name": "Standard_E4s_v5", "Quantity": 3 }
]
'@ | Set-Content -Path $jsonPath -Encoding utf8

        $jsonData = @(Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json)
        $inventory = @{}
        foreach ($item in $jsonData) {
            $skuProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $inventory[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $inventory.Count | Should -Be 1
        $inventory['Standard_E4s_v5'] | Should -Be 3
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
        $inventory = @{}
        foreach ($item in $jsonData) {
            $skuProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $skuClean = $skuProp.Trim()
                $qtyInt = [int]$qtyProp
                if ($inventory.ContainsKey($skuClean)) { $inventory[$skuClean] += $qtyInt }
                else { $inventory[$skuClean] = $qtyInt }
            }
        }
        $inventory['Standard_D2s_v5'] | Should -Be 17
    }
}
#endregion JSON Parsing Tests

#region Input Validation Tests
Describe 'InventoryFile Input Validation' {
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

    It 'Yields empty inventory when CSV has no matching column names' {
        $csvPath = Join-Path $script:TempDir 'empty.csv'
        @"
Foo,Bar
a,b
"@ | Set-Content -Path $csvPath -Encoding utf8

        $csvData = Import-Csv -LiteralPath $csvPath
        $inventory = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $inventory[$skuProp.Trim()] = [int]$qtyProp
            }
        }
        $inventory.Count | Should -Be 0
    }
}
#endregion Input Validation Tests


#region Inventory Normalization Tests
Describe 'Inventory SKU Normalization' {
    It 'Adds Standard_ prefix to bare SKU names' {
        $inventory = @{ 'D2s_v5' = 10 }
        $normalizedInventory = @{}
        foreach ($key in @($inventory.Keys)) {
            $clean = $key -replace '^Standard_Standard_', 'Standard_'
            if ($clean -notmatch '^Standard_') { $clean = "Standard_$clean" }
            $normalizedInventory[$clean] = $inventory[$key]
        }
        $normalizedInventory.Keys | Should -Contain 'Standard_D2s_v5'
    }

    It 'Strips double Standard_ prefix' {
        $inventory = @{ 'Standard_Standard_D2s_v5' = 10 }
        $normalizedInventory = @{}
        foreach ($key in @($inventory.Keys)) {
            $clean = $key -replace '^Standard_Standard_', 'Standard_'
            if ($clean -notmatch '^Standard_') { $clean = "Standard_$clean" }
            $normalizedInventory[$clean] = $inventory[$key]
        }
        $normalizedInventory.Keys | Should -Contain 'Standard_D2s_v5'
        $normalizedInventory.Keys | Should -Not -Contain 'Standard_Standard_D2s_v5'
    }

    It 'Preserves correctly prefixed SKU names' {
        $inventory = @{ 'Standard_E4s_v5' = 5 }
        $normalizedInventory = @{}
        foreach ($key in @($inventory.Keys)) {
            $clean = $key -replace '^Standard_Standard_', 'Standard_'
            if ($clean -notmatch '^Standard_') { $clean = "Standard_$clean" }
            $normalizedInventory[$clean] = $inventory[$key]
        }
        $normalizedInventory['Standard_E4s_v5'] | Should -Be 5
    }

    It 'Derives SkuFilter from inventory keys' {
        $inventory = @{ 'Standard_D2s_v5' = 10; 'Standard_E4s_v5' = 5 }
        $skuFilter = @($inventory.Keys)
        $skuFilter.Count | Should -Be 2
        $skuFilter | Should -Contain 'Standard_D2s_v5'
        $skuFilter | Should -Contain 'Standard_E4s_v5'
    }
}
#endregion Inventory Normalization Tests

#region Mutual Exclusion Tests
Describe 'Inventory Parameter Mutual Exclusion' {
    It 'Inventory and InventoryFile cannot both be specified (logic check)' {
        $inventory = @{ 'Standard_D2s_v5' = 10 }
        $inventoryFile = 'somefile.csv'
        { if ($inventory -and $inventoryFile) { throw "Cannot specify both -Inventory and -InventoryFile. Use one or the other." } } | Should -Throw '*Cannot specify both*'
    }

    It 'GenerateInventoryTemplate and JsonOutput cannot both be specified (logic check)' {
        $generateInventoryTemplate = $true
        $jsonOutput = $true
        { if ($generateInventoryTemplate -and $jsonOutput) { throw "Cannot use -GenerateInventoryTemplate with -JsonOutput." } } | Should -Throw '*Cannot use -GenerateInventoryTemplate*'
    }
}
#endregion Mutual Exclusion Tests

