#!/bin/bash
# =============================================================================
# 01_add_read_groups.sh
# Adds @RG (read group) tags to all BAM files in the input directory.
# LUMPY requires read group information to function correctly.
#
# Usage:
#   bash 01_add_read_groups.sh
#
# Prerequisites:
#   - SAMtools installed and on PATH
#   - BAM files in the INPUT_DIR directory
# =============================================================================

set -euo pipefail

# ---- Configuration (edit these) ----
INPUT_DIR="data"                  # Directory containing raw BAM files
OUTPUT_DIR="data/read_group"      # Output directory for BAMs with read groups
PLATFORM="ILLUMINA"              # Sequencing platform

# ---- Main ----
if [ ! -d "${INPUT_DIR}" ]; then
    echo "ERROR: Input directory '${INPUT_DIR}' not found."
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"

total=0
processed=0

for bam in "${INPUT_DIR}"/*.bam; do
    [ -f "${bam}" ] || { echo "No BAM files found in ${INPUT_DIR}"; exit 1; }

    sample_name=$(basename "${bam}" .bam)
    output="${OUTPUT_DIR}/${sample_name}_rg.bam"

    ((total++))

    if [ -f "${output}" ]; then
        echo "SKIP: ${output} already exists."
        continue
    fi

    echo "Processing ${bam} -> ${output}"

    samtools addreplacerg \
        -r "ID:1" \
        -r "SM:${sample_name}" \
        -r "LB:lib1" \
        -r "PL:${PLATFORM}" \
        -r "PU:unit1" \
        -o "${output}" \
        "${bam}"

    ((processed++))
done

echo "==========================================================="
echo "Read group tagging complete."
echo "Total BAM files found: ${total}"
echo "Processed:             ${processed}"
echo "Output directory:      ${OUTPUT_DIR}"
echo "==========================================================="
