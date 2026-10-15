#!/bin/bash
# 07_duplicate_samples.sh: turn the one Assignment 1 sample into N distinct samples.
# Copies the dedup BAM, its index and the recal table for each new sample, then
# writes the sample list the array script reads. Small copies, so run on the head node.
# Safe to rerun: files that already exist are skipped.
# Usage: bash scripts/07_duplicate_samples.sh
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"
require_vars SAMPLE SAMPLE_PREFIX N_SAMPLES SAMPLE_LIST BAM_DIR DEDUP_BAM RECAL_TABLE

# The three files ApplyBQSR needs, as <source file>:<suffix> pairs.
# Suffixes must match the names in config.env (${SAMPLE}_dedup.bam and so on).
SOURCE_FILES=(
  "${DEDUP_BAM}:_dedup.bam"
  "${DEDUP_BAM}.bai:_dedup.bam.bai"
  "${RECAL_TABLE}:_recal.table"
)

# Name of sample number $1, for example sample_01.
sample_name() {
  printf '%s_%02d' "${SAMPLE_PREFIX}" "$1"
}

# Stop early if a source file is missing.
check_sources() {
  local pair source_file
  for pair in "${SOURCE_FILES[@]}"; do
    source_file=${pair%%:*}
    if [ ! -f "${source_file}" ]; then
      echo "ERROR: missing ${source_file}. Run Assignment 1 first." >&2
      return 1
    fi
  done
}

# Copy one file unless the target exists.
copy_file() {
  local source_file=$1 target_file=$2
  if [ -e "${target_file}" ]; then
    echo "skip (exists): ${target_file}"
    return 0
  fi
  cp "${source_file}" "${target_file}"
  echo "copied: ${target_file}"
}

# Copy all three files for one new sample.
duplicate_sample() {
  local new_sample=$1 pair source_file suffix
  for pair in "${SOURCE_FILES[@]}"; do
    source_file=${pair%%:*}
    suffix=${pair##*:}
    copy_file "${source_file}" "${BAM_DIR}/${new_sample}${suffix}"
  done
}

# Write one sample name per line.
write_sample_list() {
  local number
  : > "${SAMPLE_LIST}"
  for number in $(seq 1 "${N_SAMPLES}"); do
    echo "$(sample_name "${number}")" >> "${SAMPLE_LIST}"
  done
}

# Print full md5 hashes. Identical BAMs must show the same hash.
verify_copies() {
  echo
  echo "=== md5 of every dedup BAM (full hashes) ==="
  md5sum "${DEDUP_BAM}" "${BAM_DIR}/${SAMPLE_PREFIX}"_*_dedup.bam
}

echo "Duplicating ${SAMPLE} into ${N_SAMPLES} samples"
check_sources
for number in $(seq 1 "${N_SAMPLES}"); do
  duplicate_sample "$(sample_name "${number}")"
done
write_sample_list
echo "Sample list: ${SAMPLE_LIST}"
verify_copies
