# Image Compatibility Checking

[← Back to README](../README.md)

The script can verify which VM SKUs are compatible with specific Azure Marketplace images, checking Generation (Gen1/Gen2) and Architecture (x64/ARM64) requirements.

## Option 1: Interactive Search (Recommended for Discovery)

Run the script **without** `-NoPrompt` and **without** `-ImageURN`:

```powershell
.\Get-AzVMAvailability.ps1 -Region eastus -EnableDrillDown
```

When prompted **"Check SKU compatibility with a specific VM image?"**, answer `y`, then you'll see options:

```
Select image (1-16, custom, search, or Enter to skip): search
```

Type **`search`** and enter keywords like:
- `ubuntu` - finds Ubuntu images
- `dsvm` or `data science` - finds Data Science VMs
- `windows` - finds Windows Server images
- `rhel` - finds Red Hat images
- `mariner` - finds Azure Linux (CBL-Mariner)

The script queries Azure Marketplace and shows matching publishers/offers, then lets you drill down to pick a specific SKU.

## Option 2: Common Images Quick-Pick

The interactive prompt shows **16 predefined common images** organized by category:

| Category     | Images                                             |
| ------------ | -------------------------------------------------- |
| Linux        | Ubuntu 22.04/24.04, RHEL 9, Debian 12, Azure Linux |
| Windows      | Server 2022, Server 2019, Windows 11               |
| Data Science | DSVM Ubuntu/Windows, Azure ML Workstation          |
| HPC          | Ubuntu HPC, AlmaLinux HPC                          |
| Gen1 Legacy  | Ubuntu 22.04 Gen1, Windows Server 2022 Gen1        |

Just type `1-16` to pick one directly, or type `custom` to enter a full URN manually.

## Option 3: Direct URN Parameter

If you already know the image URN, pass it directly:

```powershell
# Check ARM64 compatibility for Ubuntu ARM64 image
.\Get-AzVMAvailability.ps1 `
    -Region "eastus","westus2" `
    -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest" `
    -SkuFilter "Standard_D*ps*"

# Check Gen2 compatibility for Windows Server 2022
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -ImageURN "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest" `
    -EnableDrillDown
```

## Option 4: Combine with SKU Wildcards

Use `-SkuFilter` with wildcards to find specific VM types compatible with your image:

```powershell
# Find all ARM64-compatible D-series SKUs for ARM64 Ubuntu
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -SkuFilter "Standard_D*ps*" `
    -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest"
```

## Interactive Search Flow Example

```
Check SKU compatibility with a specific VM image? (y/N): y

COMMON VM IMAGES:
-------------------------------------------------------------------------------------
#    Image Name                               Gen    Arch    Category
-------------------------------------------------------------------------------------
1    Ubuntu 22.04 LTS (Gen2)                  Gen2   x64     Linux
2    Ubuntu 24.04 LTS (Gen2)                  Gen2   x64     Linux
3    Ubuntu 22.04 ARM64                       Gen2   ARM64   Linux
...
16   Windows Server 2022 (Gen1)               Gen1   x64     Gen1
-------------------------------------------------------------------------------------
Or type: 'custom' for manual URN | 'search' to browse Azure Marketplace | Enter to skip

Select image (1-16, custom, search, or Enter to skip): search

Enter search term (e.g., 'ubuntu', 'data science', 'windows', 'dsvm'): data science
Searching Azure Marketplace...

Results matching 'data science':
   1. [Offer    ] microsoft-dsvm > ubuntu-2204
   2. [Offer    ] microsoft-dsvm > dsvm-win-2022

Select (1-2) or Enter to skip: 1
...
Selected: microsoft-dsvm:ubuntu-2204:2204-gen2:latest
```

## Image Compatibility Output

When an image is specified, the drill-down view shows additional columns:

| Column | Description                                       |
| ------ | ------------------------------------------------- |
| Gen    | SKU's supported generations (1, 2, or 1,2)        |
| Arch   | SKU's CPU architecture (x64 or Arm64)             |
| Img    | Compatibility: ✓ (compatible) or ✗ (incompatible) |

SKUs that are available but **incompatible** with your image are shown in dark yellow to help you quickly identify the issue.
