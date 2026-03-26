# Azure VM SKU Upgrade Paths

> **Version:** 1.1.0 | **Last Updated:** 2026-07-21
>
> **Source:** [Microsoft VM Migration Guides](https://learn.microsoft.com/azure/virtual-machines/sizes/migration-guides)
>
> **Programmatic companion:** [`data/UpgradePath.json`](data/UpgradePath.json)

This file documents Microsoft's recommended upgrade paths for Azure VM SKU families
that are retired, scheduled for retirement, or classified as older generation (Medium Risk).
Each family entry provides up to three upgrade recommendations:

| Column | Meaning |
|--------|---------|
| **Drop-in** | Lowest risk replacement — minimal change, validated compatibility |
| **Future-proof** | Latest generation — best long-term investment (may require Gen2 OS / NVMe) |
| **Cost-optimized** | AMD-based or alternative architecture — prioritizes lowest cost |

---

## General Purpose

### Av1 — Entry-Level *(Retired 2024-08-31)*

Original A-series (A0–A11, Basic_A). No direct D-family successor — workloads should
move to B-series (burstable) or D-series (general purpose).

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Bsv2 | Standard_B4s_v2 | — | Closest burstable replacement for entry-level/test workloads |
| **Future-proof** | Dsv5 | Standard_D4s_v5 | — | General-purpose v5 for production workloads graduating from A-series |
| **Cost-optimized** | Basv2 | Standard_B4as_v2 | — | AMD burstable for lowest cost dev/test |

---

### Dv1 — General Purpose *(Retired 2024-08-31)*

Original D-series (D1–D14, DS1–DS14).

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Dsv5 | Standard_D4s_v5 | — | Same family, SCSI disk, Gen1+Gen2 OS — minimal risk |
| **Future-proof** | Dsv6 | Standard_D4s_v6 | Gen2 OS, NVMe driver | NVMe disk controller, Emerald Rapids, higher IOPS |
| **Cost-optimized** | Dasv5 | Standard_D4as_v5 | — | AMD EPYC, typically 5-15% lower cost |

---

### Dv2 / DSv2 — General Purpose *(Retiring 2027-03-31)*

Workhorse D-series v2 with Premium SSD support.

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Dsv5 | Standard_D4s_v5 | — | Same vCPU/memory ratios, SCSI disk, Gen1+Gen2 — safest Dv2 migration |
| **Future-proof** | Dsv6 | Standard_D4s_v6 | Gen2 OS, NVMe driver | Latest D-series: NVMe, higher storage IOPS, higher network bandwidth |
| **Cost-optimized** | Dasv5 | Standard_D4as_v5 | — | AMD EPYC, often 5-15% lower cost for same specs |

---

### Dv3 / Dsv3 — General Purpose *(Retiring 2027-09-30)*

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Dsv5 | Standard_D4s_v5 | — | Direct successor, same vCPU/memory ratios, SCSI, Gen1+Gen2 |
| **Future-proof** | Dsv6 | Standard_D4s_v6 | Gen2 OS, NVMe driver | NVMe, Emerald Rapids, significantly higher throughput |
| **Cost-optimized** | Dasv6 | Standard_D4as_v6 | Gen2 OS, NVMe driver | AMD Genoa v6 with NVMe, lower cost than Intel v6 |

---

## Memory Optimized

### Ev3 / Esv3 — Memory Optimized *(Retiring 2027-09-30)*

Memory-optimized (8 GiB per vCPU) for databases, caching, in-memory analytics.

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Esv5 | Standard_E4s_v5 | — | Same 8 GiB/vCPU ratio, SCSI, Gen1+Gen2 — safest E-series migration |
| **Future-proof** | Esv6 | Standard_E4s_v6 | Gen2 OS, NVMe driver | NVMe, Emerald Rapids, best for databases long-term |
| **Cost-optimized** | Easv5 | Standard_E4as_v5 | — | AMD memory-optimized, lower cost for caching workloads |

---

### Gv1 / GSv1 — Memory + Storage *(Retired 2025-03-31)*

G/GS-series retired. No G-series successor — move to E-series (memory) or M-series
(large memory / SAP).

| Path | Target Series | Example (8 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Esv5 | Standard_E8s_v5 | — | E-series provides equivalent memory-optimized ratios |
| **Future-proof** | Esv6 | Standard_E8s_v6 | Gen2 OS, NVMe driver | Latest memory-optimized with NVMe |
| **Cost-optimized** | Easv5 | Standard_E8as_v5 | — | AMD E-series for memory workloads at lower cost |

---

### Mv1 — Large Memory / SAP *(Retiring 2027-08-31)*

M-series v1 for SAP HANA and large-memory databases.

| Path | Target Series | Example (64 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Msv2 | Standard_M64ms_v2 | SAP validation, Gen2 for large sizes | SAP-certified large-memory replacement |
| **Future-proof** | Msv3 | Standard_M64s_v3 | Gen2 OS, NVMe driver, SAP validation | Latest M-series, highest memory bandwidth |
| **Cost-optimized** | Masv3 | Standard_M64as_v3 | Gen2 OS, NVMe driver | AMD M-series v3 for non-Intel workloads |

---

## Compute Optimized

### Fv1 — Compute Optimized *(Retiring 2027-09-30)*

Fs-series (compute-optimized with Premium SSD).

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Fsv2 | Standard_F4s_v2 | — | Direct successor, higher clock speed, broad availability |
| **Future-proof** | Fasv6 | Standard_F4as_v6 | Gen2 OS, NVMe driver | AMD Genoa compute-optimized, latest F-family generation |

---

## Storage Optimized

### Lv1 — Storage Optimized *(Retired 2024-08-31)*

Ls-series with local NVMe storage.

| Path | Target Series | Example (16 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Lsv3 | Standard_L16s_v3 | — | Direct successor with NVMe local disks, higher IOPS |
| **Future-proof** | Lsv3 | Standard_L16s_v3 | — | Currently the latest storage-optimized generation |
| **Cost-optimized** | Lasv3 | Standard_L16as_v3 | — | AMD storage-optimized at lower cost |

---

## HPC

### Hv1 — HPC *(Retired 2024-09-28)*

Original H-series (H8–H16r) retired.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | HBv4 | Standard_HB176rs_v4 | HPC OS, InfiniBand drivers | Current HPC workhorse, AMD Genoa, NDR200 |
| **Future-proof** | HXv4 | Standard_HX176rs | HPC OS, InfiniBand drivers | Large-memory HPC for >200 GiB workloads |
| **Cost-optimized** | HBv3 | Standard_HB120rs_v3 | HPC OS | Lower cost, still widely available |

---

### HBv1 *(Retired 2024-09-28)*

HB60rs retired.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | HBv3 | Standard_HB120rs_v3 | HPC OS | Established HPC replacement with broad availability |
| **Future-proof** | HBv4 | Standard_HB176rs_v4 | HPC OS, NDR200 InfiniBand | Latest HPC, AMD Genoa, highest bandwidth |
| **Cost-optimized** | HBv3 | Standard_HB120rs_v3 | HPC OS | Best cost/performance for HPC |

---

### HCv1 *(Retired 2024-09-28)*

HC44rs (Intel HPC) retired.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | HBv3 | Standard_HB120rs_v3 | HPC OS, validate Intel-specific codes | Comparable HPC capability |
| **Future-proof** | HBv4 | Standard_HB176rs_v4 | HPC OS, NDR200 InfiniBand | Latest HPC generation |
| **Cost-optimized** | HBv3 | Standard_HB120rs_v3 | HPC OS | Most cost-effective HPC option |

---

## GPU

### NCv1 — GPU Compute *(Retired 2023-09-06)*

Tesla K80 GPU retired.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | NCadsA10v4 | Standard_NC8ads_A10_v4 | A10 GPU drivers, Gen2 recommended | A10 replaces K80 for inference and training |
| **Future-proof** | NCadsH100v5 | Standard_NC40ads_H100_v5 | H100 GPU drivers, Gen2 | Highest GPU compute performance |
| **Cost-optimized** | NCasT4v3 | Standard_NC4as_T4_v3 | T4 GPU drivers | T4 for cost-effective inference |

---

### NCv2 — GPU Compute *(Retired 2023-09-06)*

Tesla P100 GPU retired.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | NCadsA10v4 | Standard_NC8ads_A10_v4 | A10 GPU drivers, Gen2 recommended | A10 replaces P100 with better perf/watt |
| **Future-proof** | NCadsH100v5 | Standard_NC40ads_H100_v5 | H100 GPU drivers, Gen2 | Top-tier AI/ML training and inference |
| **Cost-optimized** | NCasT4v3 | Standard_NC4as_T4_v3 | T4 GPU drivers | Cost-effective inference |

---

### NCv3 — GPU Compute *(Retiring 2025-09-30)*

Tesla V100 GPU retiring.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | NCadsA10v4 | Standard_NC8ads_A10_v4 | A10 GPU drivers, Gen2 | A10 matches V100 GPU memory, better inference |
| **Future-proof** | NCadsH100v5 | Standard_NC40ads_H100_v5 | H100 GPU drivers, Gen2 | Maximum GPU compute for heavy training |
| **Cost-optimized** | NCasT4v3 | Standard_NC4as_T4_v3 | T4 GPU drivers | Extremely cost-effective for inference |

---

### NDv1 — GPU Training *(Retired 2023-09-06)*

Tesla P40 GPU retired.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | NDAMv4_A100 | Standard_ND96asr_v4 | A100 drivers, Gen2, InfiniBand | A100 is standard AI training replacement, 10x+ over P40 |
| **Future-proof** | NDv5 | Standard_ND96isr_H100_v5 | H100 drivers, Gen2, NDR InfiniBand | Highest training performance available |
| **Cost-optimized** | NCadsA10v4 | Standard_NC8ads_A10_v4 | A10 drivers, Gen2 | A10 for lighter training/inference at lower cost |

---

### NDv2 — GPU Training *(Retiring 2025-09-30)*

V100 with NVLink retiring.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | NDAMv4_A100 | Standard_ND96asr_v4 | A100 drivers, Gen2, InfiniBand | A100 NVLink successor, 3x throughput over V100 |
| **Future-proof** | NDv5 | Standard_ND96isr_H100_v5 | H100 drivers, Gen2, NDR InfiniBand | H100 NVLink, 6x over A100 for transformers |
| **Cost-optimized** | NDAMv4_A100 | Standard_ND96asr_v4 | A100 drivers, Gen2 | A100 is most cost-effective multi-GPU training |

---

### NVv1 — GPU Visualization *(Retired 2023-09-06)*

Tesla M60 GPU retired.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | NVadsA10v5 | Standard_NV6ads_A10_v5 | A10 GRID drivers, Gen2 recommended | A10 with fractional GPU, direct M60 replacement |
| **Future-proof** | NVadsA10v5 | Standard_NV6ads_A10_v5 | A10 GRID drivers, Gen2 | Currently the latest NV-class series |
| **Cost-optimized** | NVv4 | Standard_NV4as_v4 | AMD GPU drivers | AMD Radeon MI25 — lowest cost VDI |

---

### NVv3 — GPU Visualization *(Retiring 2025-09-30)*

M60 refresh retiring.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | NVadsA10v5 | Standard_NV6ads_A10_v5 | A10 GRID drivers, Gen2 | A10 replaces M60 with better performance |
| **Future-proof** | NVadsA10v5 | Standard_NV6ads_A10_v5 | A10 GRID drivers, Gen2 | Currently the latest NV-class series |
| **Cost-optimized** | NVv4 | Standard_NV4as_v4 | AMD GPU drivers | Budget-friendly VDI and visualization |

---

## Older Generation (Medium Risk)

These families are not retired or retiring but are classified as Medium Risk because
they are generation v1–v3 with newer successors available. Proactive migration avoids
future forced transitions.

### Av2 — Entry-Level General Purpose *(OldGen)*

A-series v2 has no newer A-series successor. Workloads should migrate to D-series
(general purpose) or B-series (burstable/dev-test).

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Dsv5 | Standard_D4s_v5 | — | General-purpose successor, Premium SSD, SCSI — safest migration |
| **Future-proof** | Dsv6 | Standard_D4s_v6 | Gen2 OS, NVMe driver | Latest D-series, Emerald Rapids, highest IOPS |
| **Cost-optimized** | Bsv2 | Standard_B4s_v2 | — | Burstable v2 for dev/test workloads with intermittent CPU |

---

### Bv1 — Burstable *(OldGen)*

Original B-series burstable VMs. Bsv2 offers better baseline performance and more
size options.

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Bsv2 | Standard_B4s_v2 | — | Direct burstable successor, improved baseline performance |
| **Future-proof** | Dsv5 | Standard_D4s_v5 | — | General-purpose for workloads outgrowing burstable model |
| **Cost-optimized** | Basv2 | Standard_B4as_v2 | — | AMD burstable v2, lowest cost option |

---

### Fv2 / Fsv2 — Compute Optimized *(OldGen)*

Fsv2 is the current compute-optimized workhorse. Fasv6 is the latest F-family
generation with AMD Genoa processors and NVMe support.

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|----------|
| **Drop-in** | Fasv6 | Standard_F4as_v6 | — | AMD compute-optimized v6, SCSI compatible, competitive pricing |

---

### Lv2 / Lsv2 — Storage Optimized *(OldGen)*

Lsv2 storage-optimized with NVMe local disks. Lsv3/Lasv3 offer more size options;
Lsv4 is the latest generation.

| Path | Target Series | Example (16 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Lsv3 | Standard_L16s_v3 | — | Direct successor, NVMe local disks, improved throughput |
| **Future-proof** | Lsv4 | Standard_L16s_v4 | Gen2 OS | Latest storage-optimized, broadest size range (2-96 vCPU) |
| **Cost-optimized** | Lasv3 | Standard_L16as_v3 | — | AMD storage-optimized, lower cost per vCPU |

---

### Lv3 / Lsv3 — Storage Optimized *(OldGen)*

Lsv3/Lasv3 storage-optimized v3. Lsv4 is the latest generation.

| Path | Target Series | Example (16 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Lsv4 | Standard_L16s_v4 | Gen2 OS | Direct successor, extended size range, improved throughput |
| **Future-proof** | Lasv4 | Standard_L16as_v4 | Gen2 OS | AMD storage-optimized v4, best price-performance |

---

### DCv2 / DCsv2 — Confidential Compute *(OldGen)*

DCsv2 with Intel SGX enclaves. DCdsv3/DCdsv5 offer larger sizes and improved TEE.

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | DCdsv3 | Standard_DC4ds_v3 | Confidential OS image | Intel TDX, larger sizes (1-48 vCPU), SGX + TDX support |
| **Future-proof** | DCadsv5 | Standard_DC4ads_v5 | Confidential OS, AMD SEV-SNP | Latest confidential compute, broadest range (2-96 vCPU) |

---

### DCv3 / DCdsv3 — Confidential Compute *(OldGen)*

DCdsv3 with Intel TDX. DCadsv5 is the latest AMD-based option.

| Path | Target Series | Example (4 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | DCadsv5 | Standard_DC4ads_v5 | Confidential OS, AMD SEV-SNP | Latest confidential compute, extended size range |

---

### NVv2 — GPU Visualization *(OldGen)*

NVv2 with NVIDIA Tesla M60. NVv4 (AMD Radeon) and NVv5 (NVIDIA A10/V710) are newer.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | NVadsA10v5 | Standard_NV6ads_A10_v5 | NVIDIA GPU drivers | A10 GPU, broader size range, better GPU-to-vCPU ratio |
| **Future-proof** | NVadsV710v5 | Standard_NV4ads_V710_v5 | NVIDIA GPU drivers | Latest V710 GPU, newest driver support |
| **Cost-optimized** | NVasv4 | Standard_NV4as_v4 | AMD GPU drivers | AMD Radeon MI25, lowest cost for standard VDI |

---

### HBv2 — HPC *(OldGen)*

HBv2 with AMD EPYC 7V12. HBv3 improved interconnect; HBv4 is the latest.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | HBv3 | Standard_HB120rs_v3 | HPC OS, InfiniBand drivers | AMD Milan, improved InfiniBand bandwidth |
| **Future-proof** | HBv4 | Standard_HB176rs_v4 | HPC OS, InfiniBand drivers | AMD Genoa, NDR 400 Gb/s, highest memory bandwidth |

---

### HBv3 — HPC *(OldGen)*

HBv3 with AMD EPYC Milan. HBv4 is the latest with Genoa.

| Path | Target Series | Example | Requirements | Rationale |
|------|--------------|---------|--------------|-----------|
| **Drop-in** | HBv4 | Standard_HB176rs_v4 | HPC OS, InfiniBand drivers | AMD Genoa, NDR 400 Gb/s, 50% more memory bandwidth |

---

### Mv2 / Msv2 — Large Memory / SAP *(OldGen)*

Msv2/Mdsv2 for SAP HANA and large in-memory databases. Mv3 offers broader sizes
and improved performance.

| Path | Target Series | Example (128 vCPU) | Requirements | Rationale |
|------|--------------|-------------------|--------------|-----------|
| **Drop-in** | Mbdsv3 | Standard_M128bds_v3 | Gen2 OS | Broader size range, NVMe, higher memory bandwidth |
| **Future-proof** | Mbsv3 | Standard_M128bs_v3 | Gen2 OS | No temp disk variant for cost savings with remote storage |

---

## Common Requirements Reference

| Requirement | Impact | Validation |
|-------------|--------|------------|
| **Gen2 OS image** | Required for v6 series and some GPU SKUs | `az vm image list --publisher Canonical --offer 0001-com-ubuntu-server-jammy --sku gen2` |
| **NVMe driver** | Required for v6 series disk controller | Check OS kernel version; Windows Server 2019+ and Ubuntu 20.04+ supported |
| **GPU drivers** | Must match target GPU model | NVIDIA: `nvidia-smi`; AMD: `rocm-smi` |
| **InfiniBand** | Required for HPC RDMA workloads | Mellanox OFED driver installation |
| **SAP validation** | Required for M-series SAP workloads | Check SAP Note 1928533 for certified sizes |

---

## Maintenance Notes

- **Update frequency:** Review quarterly or when Microsoft announces new retirements
- **Sources:** [Azure VM migration guides](https://learn.microsoft.com/azure/virtual-machines/sizes/migration-guides), [Azure Updates](https://azure.microsoft.com/updates/)
- **JSON companion:** Keep [`data/UpgradePath.json`](data/UpgradePath.json) in sync with this file
