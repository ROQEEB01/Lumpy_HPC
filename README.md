# Lumpy_HPC
This is a bioinformatics pipeline for detecting structural variants and copy number variants in genomic data using LUMPY


A [LUMPY](https://github.com/arq5x/lumpy-sv)-based structural variant (SV) and copy number variant (CNV) detection pipeline for **Mountain Pine Beetle** (*Dendroctonus ponderosae*) whole-genome resequencing data, designed to run on a SLURM-managed HPC cluster (e.g., the [Digital Research Alliance of Canada](https://alliancecan.ca/)). The script can also work for other whole-genome resequencing data. The basic requirement for the script to work is a BAM file. 

---

## Table of Contents

- [Overview](#overview)
- [Pipeline Workflow](#pipeline-workflow)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Usage](#usage)
  - [1. Configure Paths](#1-configure-paths)
  - [2. Add Read Groups](#2-add-read-groups)
  - [3. Sort and Index BAMs](#3-sort-and-index-bams)
  - [4. Run LUMPY](#4-run-lumpy)
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

```text
Raw BAM files
      │
      ▼
┌─────────────────────────┐
│ 01  Add Read Groups      │  01_add_read_groups.sh
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ 02  Sort & Index BAMs    │  02_sort_index_bams.slm
└────────────┬────────────┘
             ▼
┌─────────────────────────┐
│ 03  Index BAMs (opt.)    │  03_index_bams.slm
└────────────┬────────────┘   (only if BAMs are sorted but not indexed)
             ▼
┌─────────────────────────┐
│ 04  Run LUMPY            │  04_run_lumpy.slm
│  • Discordant reads      │
│  • Split reads           │
│  • SV calling            │
│  • CNV filtering         │
│  • Summary statistics    │
└────────────┬────────────┘
             ▼
      VCF & Summary Files
