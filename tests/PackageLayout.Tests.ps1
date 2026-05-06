Describe 'PSGallery package layout' {
    BeforeAll {
        $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
        $stageScript = Join-Path $repoRoot 'tools' 'Stage-ModulePackage.ps1'
        $stageRoot = Join-Path $TestDrive 'staging'
        $stageResult = & $stageScript -RepoRoot $repoRoot -StagingRoot $stageRoot
        $script:StagedModulePath = $stageResult.ModulePath

        $script:PublicPackageAssets = @(
            'README.md',
            'LICENSE',
            'CHANGELOG.md',
            'data/UpgradePath.json',
            'data/UpgradePath.md',
            'docs/agent-integration.md',
            'docs/cloud-environments.md',
            'docs/codespaces.md',
            'docs/Excel-Legend-Reference.md',
            'docs/image-compatibility.md',
            'docs/inventory-planning.md',
            'docs/lifecycle-recommendations.md',
            'docs/LifecycleRecommendationCoreDifferences.md',
            'docs/local-installation.md',
            'docs/output-and-pricing.md',
            'docs/parameters.md',
            'docs/region-presets.md',
            'docs/usage-examples.md',
            'examples/ARG-Queries.md',
            'examples/fleet-bom.csv',
            'examples/fleet-bom.json'
        )
    }

    It 'Stages the module manifest and loader' {
        Test-Path -LiteralPath (Join-Path $script:StagedModulePath 'AzVMAvailability.psd1') -PathType Leaf | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $script:StagedModulePath 'AzVMAvailability.psm1') -PathType Leaf | Should -BeTrue
    }

    It 'Stages UpgradePath data where the public function can resolve it' {
        $publicRoot = Join-Path $script:StagedModulePath 'Public'
        $runtimeCandidate = Join-Path $publicRoot '..' 'data' 'UpgradePath.json'
        Test-Path -LiteralPath $runtimeCandidate -PathType Leaf | Should -BeTrue
    }

    It 'Stages public package assets' {
        foreach ($relativePath in $script:PublicPackageAssets) {
            $assetPath = Join-Path $script:StagedModulePath $relativePath
            Test-Path -LiteralPath $assetPath -PathType Leaf | Should -BeTrue
        }
    }

    It 'Does not stage repo-only implementation and CI folders' {
        $repoOnlyFolders = @('.github', 'tests', 'tools', 'functions', 'backups', 'dev')
        foreach ($relativePath in $repoOnlyFolders) {
            $folderPath = Join-Path $script:StagedModulePath $relativePath
            Test-Path -LiteralPath $folderPath -PathType Container | Should -BeFalse
        }
    }

    It 'Produces a valid staged manifest' {
        $manifestPath = Join-Path $script:StagedModulePath 'AzVMAvailability.psd1'
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
    }
}
