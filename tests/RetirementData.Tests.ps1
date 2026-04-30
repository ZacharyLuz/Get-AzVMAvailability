# RetirementData.Tests.ps1
# Validates the static retirement table in Get-SkuRetirementInfo.ps1
# Run with: Invoke-Pester .\tests\RetirementData.Tests.ps1 -Output Detailed

# BeforeDiscovery runs before test registration — data is available for -ForEach
BeforeDiscovery {
    # Parse the raw source to extract retirement entries for parameterized tests
    $sourceFile = Join-Path $PSScriptRoot '..' 'AzVMAvailability' 'Private' 'SKU' 'Get-SkuRetirementInfo.ps1'
    $sourceContent = Get-Content $sourceFile -Raw

    $entryMatches = [regex]::Matches(
        $sourceContent,
        "@\{\s*Pattern\s*=\s*'(?<pat>[^']+)';\s*Series\s*=\s*'(?<ser>[^']+)';\s*RetireDate\s*=\s*'(?<date>[^']+)';\s*Status\s*=\s*'(?<stat>[^']+)'\s*\}"
    )
    $script:ParsedEntries = @(foreach ($m in $entryMatches) {
        @{
            Pattern    = $m.Groups['pat'].Value
            Series     = $m.Groups['ser'].Value
            RetireDate = $m.Groups['date'].Value
            Status     = $m.Groups['stat'].Value
        }
    })

    $script:RetiredEntries  = @($script:ParsedEntries | Where-Object { $_.Status -eq 'Retired' })
    $script:RetiringEntries = @($script:ParsedEntries | Where-Object { $_.Status -eq 'Retiring' })

    $script:KnownRetiring = @(
        @{ Sku = 'Standard_D4';           ExpectedSeries = 'Dv1' }
        @{ Sku = 'Standard_DS14';         ExpectedSeries = 'Dv1' }
        @{ Sku = 'Standard_D4_v2';        ExpectedSeries = 'Dv2' }
        @{ Sku = 'Standard_DS14_v2';      ExpectedSeries = 'Dv2' }
        @{ Sku = 'Standard_A4_v2';        ExpectedSeries = 'Av2' }
        @{ Sku = 'Standard_A4m_v2';       ExpectedSeries = 'Av2' }
        @{ Sku = 'Standard_B4ms';         ExpectedSeries = 'Bv1' }
        @{ Sku = 'Standard_G4';           ExpectedSeries = 'G/GS' }
        @{ Sku = 'Standard_GS4';          ExpectedSeries = 'G/GS' }
        @{ Sku = 'Standard_F4s';          ExpectedSeries = 'Fsv1' }
        @{ Sku = 'Standard_F8s_v2';       ExpectedSeries = 'Fsv2' }
        @{ Sku = 'Standard_F16s_v2';      ExpectedSeries = 'Fsv2' }
        @{ Sku = 'Standard_L8s';          ExpectedSeries = 'Lsv1' }
        @{ Sku = 'Standard_L8s_v2';       ExpectedSeries = 'Lsv2' }
        @{ Sku = 'Standard_M192idms_v2';  ExpectedSeries = 'M192iv2' }
        @{ Sku = 'Standard_M192is_v2';    ExpectedSeries = 'M192iv2' }
        @{ Sku = 'Standard_M64s';         ExpectedSeries = 'Mv1' }
        @{ Sku = 'Standard_NV12s_v3';     ExpectedSeries = 'NVv3' }
        @{ Sku = 'Standard_NV16as_v4';    ExpectedSeries = 'NVv4' }
        @{ Sku = 'Standard_NV32as_v4';    ExpectedSeries = 'NVv4' }
        @{ Sku = 'Standard_NP10s';        ExpectedSeries = 'NP' }
        @{ Sku = 'Standard_NP40s';        ExpectedSeries = 'NP' }
    )

    $script:KnownRetired = @(
        @{ Sku = 'Standard_H8';           ExpectedSeries = 'H' }
        @{ Sku = 'Standard_H16r';         ExpectedSeries = 'H' }
        @{ Sku = 'Standard_HB60rs';       ExpectedSeries = 'HBv1' }
        @{ Sku = 'Standard_HC44rs';       ExpectedSeries = 'HC' }
        @{ Sku = 'Standard_NC6';          ExpectedSeries = 'NCv1' }
        @{ Sku = 'Standard_NC24r';        ExpectedSeries = 'NCv1' }
        @{ Sku = 'Standard_NC6s_v2';      ExpectedSeries = 'NCv2' }
        @{ Sku = 'Standard_NC6s_v3';      ExpectedSeries = 'NCv3' }
        @{ Sku = 'Standard_ND6s';         ExpectedSeries = 'NDv1' }
        @{ Sku = 'Standard_ND40rs_v2';    ExpectedSeries = 'NDv2' }
        @{ Sku = 'Standard_NV6';          ExpectedSeries = 'NVv1' }
        @{ Sku = 'Basic_A4';              ExpectedSeries = 'Av1' }
        @{ Sku = 'Standard_A4';           ExpectedSeries = 'Av1' }
    )

    $script:CurrentGenSkus = @(
        @{ Sku = 'Standard_D4s_v5' }
        @{ Sku = 'Standard_E8s_v5' }
        @{ Sku = 'Standard_B4as_v2' }
        @{ Sku = 'Standard_L8s_v3' }
        @{ Sku = 'Standard_M128s_v2' }
        @{ Sku = 'Standard_NC24ads_A100_v4' }
        @{ Sku = 'Standard_NV36ads_A10_v5' }
        @{ Sku = 'Standard_HB120rs_v3' }
        @{ Sku = 'Standard_DC4s_v3' }
        @{ Sku = 'Standard_E96ias_v5' }
    )
}

BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-SkuRetirementInfo')))

    # Re-parse source for assertions that need Run-phase access
    $sourceFile = Join-Path $PSScriptRoot '..' 'AzVMAvailability' 'Private' 'SKU' 'Get-SkuRetirementInfo.ps1'
    $sourceContent = Get-Content $sourceFile -Raw
    if ($sourceContent -match 'Last verified:\s*(\d{4}-\d{2}-\d{2})') {
        $script:LastVerifiedDate = [datetime]$Matches[1]
    } else {
        $script:LastVerifiedDate = $null
    }

    # Re-count entries at Run phase for the count assertion
    $entryMatches = [regex]::Matches(
        $sourceContent,
        "@\{\s*Pattern\s*=\s*'[^']+';\s*Series\s*=\s*'[^']+';\s*RetireDate\s*=\s*'[^']+';\s*Status\s*=\s*'[^']+'\s*\}"
    )
    $script:EntryCount = $entryMatches.Count
}

# ── Structure & field validation ────────────────────────────────────────────

Describe 'Retirement table structure' {
    It 'Has at least 15 retirement entries' {
        $script:EntryCount | Should -BeGreaterOrEqual 15
    }

    It 'Has a "Last verified" date comment in the source' {
        $script:LastVerifiedDate | Should -Not -BeNullOrEmpty
    }

    It '"Last verified" date is parsable and not in the future' {
        $script:LastVerifiedDate | Should -Not -BeNullOrEmpty
        $script:LastVerifiedDate | Should -BeOfType ([datetime])
        $script:LastVerifiedDate | Should -BeLessOrEqual ([datetime]::UtcNow.Date.AddDays(1))
    }

    It '"Last verified" date is no more than 90 days old (opt-in via $env:GAZVM_CHECK_RETIREMENT_FRESHNESS=1)' -Skip:(-not $env:GAZVM_CHECK_RETIREMENT_FRESHNESS) {
        $daysSince = ([datetime]::UtcNow.Date - $script:LastVerifiedDate).Days
        $daysSince | Should -BeLessOrEqual 90 -Because "table was last verified $($script:LastVerifiedDate.ToString('yyyy-MM-dd')) ($daysSince days ago)"
    }

    It "'<Series>' has a non-empty Pattern" -ForEach $script:ParsedEntries {
        $Pattern | Should -Not -BeNullOrEmpty
    }

    It "'<Series>' Pattern is valid regex" -ForEach $script:ParsedEntries {
        { [regex]::new($Pattern) } | Should -Not -Throw
    }

    It "'<Series>' RetireDate is valid YYYY-MM-DD" -ForEach $script:ParsedEntries {
        $RetireDate | Should -Match '^\d{4}-\d{2}-\d{2}$'
        { [datetime]::ParseExact($RetireDate, 'yyyy-MM-dd', $null) } | Should -Not -Throw
    }

    It "'<Series>' Status is Retired or Retiring" -ForEach $script:ParsedEntries {
        $Status | Should -BeIn @('Retired', 'Retiring')
    }
}

# ── No duplicates ───────────────────────────────────────────────────────────

Describe 'Retirement table uniqueness' {
    It 'Has no duplicate Series names' {
        $seriesNames = $script:ParsedEntries | ForEach-Object { $_.Series }
        $dupes = $seriesNames | Group-Object | Where-Object { $_.Count -gt 1 }
        $dupes | Should -BeNullOrEmpty -Because "duplicate series found: $($dupes.Name -join ', ')"
    }

    It 'Has no duplicate Patterns' {
        $patterns = $script:ParsedEntries | ForEach-Object { $_.Pattern }
        $dupes = $patterns | Group-Object | Where-Object { $_.Count -gt 1 }
        $dupes | Should -BeNullOrEmpty -Because "duplicate patterns found: $($dupes.Name -join ', ')"
    }
}

# ── Date sanity ─────────────────────────────────────────────────────────────

Describe 'Retirement date sanity' {
    It "'<Series>' (Retired) retire date (<RetireDate>) is in the past" -ForEach $script:RetiredEntries {
        [datetime]$RetireDate | Should -BeLessThan ([datetime]::UtcNow.Date.AddDays(1))
    }

    It "'<Series>' (Retiring) retire date (<RetireDate>) is within 5 years" -ForEach $script:RetiringEntries {
        [datetime]$RetireDate | Should -BeLessThan ([datetime]::UtcNow.Date.AddYears(5))
    }
}

# ── Pattern matching known SKUs ─────────────────────────────────────────────

Describe 'Known SKU detection' {
    It "Detects <Sku> as <ExpectedSeries> (Retiring)" -ForEach $script:KnownRetiring {
        $result = Get-SkuRetirementInfo -SkuName $Sku
        $result | Should -Not -BeNullOrEmpty
        $result.Series | Should -Be $ExpectedSeries
        $result.Status | Should -Be 'Retiring'
    }

    It "Detects <Sku> as <ExpectedSeries> (Retired)" -ForEach $script:KnownRetired {
        $result = Get-SkuRetirementInfo -SkuName $Sku
        $result | Should -Not -BeNullOrEmpty
        $result.Series | Should -Be $ExpectedSeries
        $result.Status | Should -Be 'Retired'
    }
}

# ── No false positives ─────────────────────────────────────────────────────

Describe 'No false positives on current-gen SKUs' {
    It "Does not flag <Sku> as retired or retiring" -ForEach $script:CurrentGenSkus {
        $result = Get-SkuRetirementInfo -SkuName $Sku
        $result | Should -BeNullOrEmpty
    }
}
