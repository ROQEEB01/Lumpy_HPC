# Lumpy_MPB

A [LUMPY](https://github.com/arq5x/lumpy-sv)-based structural variant (SV) and copy number variant (CNV) detection pipeline for **Mountain Pine Beetle** (*Dendroctonus ponderosae*) whole-genome resequencing data, designed to run on a SLURM-managed HPC cluster (e.g., the [Digital Research Alliance of Canada](https://alliancecan.ca/)).

---

## Table of Contents

- [Overview](#overview)
- [Pipeline Workflow](#pipeline-workflow)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Usage](#usage)
- [Output](#output)
- [Notes](#notes)
- [References](#references)
- [License](#license)

---

## Overview

This pipeline takes aligned BAM files from MPB whole-genome resequencing data and performs the following steps:

1. **Add read group tags** — required by LUMPY for sample identification
2. **Sort and index BAM files** — coordinate-sorted BAMs with `.bai` indices
3. **Extract discordant and split reads** — evidence signals used by LUMPY
4. **Call structural variants** — using LUMPY Express
5. **Filter for CNVs** — retains deletions (`DEL`) and duplications (`DUP`)
6. **Generate summary statistics** — per-sample and combined CSV reports

---

## Pipeline Workflow

```
Raw BAM files
      │
      ▼
┌─────────────────────────┐
│  01  Add Read Groups    │  01_add_read_groups.sh
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  02  Sort & Index BAMs  │  02_sort_index_bams.slm
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  03  Index BAMs (opt.)  │  03_index_bams.slm
└────────────┬────────────┘  (only if BAMs are sorted but not indexed)
             │
             ▼
┌─────────────────────────┐
│  04  Run LUMPY          │  04_run_lumpy.slm
│   • Discordant reads    │
│   • Split reads         │
│   • SV calling          │
│   • CNV filtering       │
│   • Summary statistics  │
└────────────┬────────────┘
             │
             ▼
      VCF & Summary Files
```

---

## Prerequisites

### Software

| Tool | Version Tested | Purpose |
|------|---------------|---------|
| [SAMtools](http://www.htslib.org/) | 1.17 / 1.20 | BAM manipulation and indexing |
| [BCFtools](http://www.htslib.org/) | 1.16 | VCF filtering |
| [BEDTools](https://bedtools.readthedocs.io/) | 2.30.0 | Genomic interval operations |
| [LUMPY](https://github.com/arq5x/lumpy-sv) | 0.2.13 | Structural variant detection |
| [samblaster](https://github.com/GregoryFaust/samblaster) | 0.1.26 | Duplicate marking |
| [sambamba](https://lomereiter.github.io/sambamba/) | 0.8.0 | Fast BAM processing |
| Python | 2.7.18 | Required by LUMPY helper scripts |
| [pysam](https://pysam.readthedocs.io/) | latest | Python interface to SAMtools |
| [NumPy](https://numpy.org/) | latest | Numerical operations |

> **HPC users:** On Compute Canada / DRAC clusters, most dependencies are available via `module load`. See the `module load` lines at the top of each `.slm` script.

### Data

- **Aligned BAM files** — one per sample, produced by [BWA-MEM](https://github.com/lh3/bwa) or equivalent
- **Reference genome** — FASTA file (e.g., `MPB_reference.fna`)

---

## Repository Structure

```
Lumpy_MPB/
├── 01_add_read_groups.sh           # Add @RG tags to BAM files
├── 02_sort_index_bams.slm          # SLURM job: sort and index BAMs
├── 03_index_bams.slm               # SLURM job: index already-sorted BAMs
├── 04_run_lumpy.slm                # SLURM job: LUMPY SV/CNV pipeline
├── lumpyexpress.config.example     # Example LUMPY Express config file
├── .gitignore
├── LICENSE
└── README.md
```

---

## Usage

### 1. Configure Paths

Each script has a **Configuration** section at the top. Edit the placeholder paths before running:

```bash
# In every .slm file, update:
#SBATCH --account=<your-allocation>
#SBATCH --mail-user=<your-email>

# And the working directory variables, e.g.:
BASE_DIR="/path/to/your/working/directory"
```

### 2. Add Read Groups

LUMPY requires `@RG` (read group) headers in each BAM file. If your BAMs are missing them:

```bash
bash 01_add_read_groups.sh
```

This reads BAMs from `data/` and writes tagged BAMs to `data/read_group/`.

### 3. Sort and Index BAMs

Submit the SLURM sorting and indexing job:

```bash
sbatch 02_sort_index_bams.slm
```

If your BAMs are already coordinate-sorted but only need `.bai` index files:

```bash
sbatch 03_index_bams.slm
```

### 4. Run LUMPY

Submit the main analysis job:

```bash
sbatch 04_run_lumpy.slm
```

This script will, for each sample:

1. Extract discordant read pairs (`-F 1294`)
2. Extract split reads via the LUMPY helper script
3. Generate a per-sample `lumpyexpress.config` with auto-detected tool paths
4. Run LUMPY Express
5. Filter the output VCF for `DEL` and `DUP` variants
6. Produce a per-sample summary and copy key files to the results directory

---

## Output

All results are written to the `lumpy_results/` directory:

| File | Description |
|------|-------------|
| `<sample>.lumpy.vcf` | Raw LUMPY structural variant calls |
| `<sample>.cnv.vcf.gz` | Filtered CNVs (DEL + DUP), bgzipped |
| `<sample>.cnv.vcf.gz.tbi` | Tabix index for the filtered VCF |
| `<sample>.cnv_summary.txt` | Per-sample counts of deletions and duplications |
| `all_samples_summary.csv` | Combined summary table across all samples |

Each sample also has its own subdirectory containing intermediate files (discordant reads, split reads, LUMPY config, etc.).

### Example Summary CSV

```
Sample,Total_CNVs,Deletions,Duplications
sample_01,142,98,44
sample_02,87,61,26
```

---

## Notes

- **LUMPY Express** is a convenience wrapper around the core LUMPY engine. The pipeline dynamically generates a per-sample configuration file with correct tool paths detected from loaded modules.
- **Resumable:** Samples with existing output files are automatically skipped, so the pipeline is safe to re-run after partial failures or job timeouts.
- **Disk-aware:** Large intermediate files (`*.name.bam`, `*.discordants.unsort.bam`) are removed after each sample completes.
- **Python 2.7** is required by LUMPY's helper scripts (`pairend_distro.py`, `extractSplitReads_BwaMem`, etc.). This is a known LUMPY limitation.
- `03_index_bams.slm` is a convenience script for cases where BAMs are already sorted but lack index files. In a typical run, `02_sort_index_bams.slm` handles both sorting and indexing.

---

## References

Layer, R. M., Chiang, C., Quinlan, A. R., & Hall, I. M. (2014). LUMPY: a probabilistic framework for structural variant discovery. *Genome Biology*, 15(6), R84. https://doi.org/10.1186/gb-2014-15-6-r84

---

## License

This project is licensed under the BSD 3-Clause License. See [LICENSE](LICENSE) for details.
