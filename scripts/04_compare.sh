#!/bin/bash
# 04_compare.sh: compare the three VCFs and the recalibrated BAMs.
# Not a Slurm job: short and light, so run it on the head node.
# Usage: bash scripts/04_compare.sh      Output: ${WORK}/${SAMPLE}_compare_results.txt
set -uo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"
source "${PROJECT_DIR}/lib/steps.sh"      # for tool_label and recalibrated_bam

MODULE_VCF=${VCF_DIR}/${SAMPLE}_$(tool_label module).vcf.gz
CONTAINER_VCF=${VCF_DIR}/${SAMPLE}_$(tool_label container).vcf.gz
PARABRICKS_VCF=${VCF_DIR}/${SAMPLE}_$(tool_label parabricks).vcf.gz
RESULTS=${WORK}/${SAMPLE}_compare_results.txt

# Variant lines only (no header).
body() {
  zcat "$1" | grep -v '^#'
}

# Print the full md5 of a file's decompressed text.
full_md5() {
  zcat "$1" | md5sum | cut -d' ' -f1
}

# Compare two VCFs: full file hashes, variant lines, then header differences.
compare_vcf() {
  local a=$1 b=$2
  echo
  echo "== $(basename "${a}") vs $(basename "${b}")"
  echo "full file md5, first:  $(full_md5 "${a}")"
  echo "full file md5, second: $(full_md5 "${b}")"

  if [ "$(body "${a}" | md5sum)" = "$(body "${b}" | md5sum)" ]; then
    echo "variant lines: IDENTICAL"
  else
    echo "variant lines: DIFFERENT, first differences:"
    diff <(body "${a}") <(body "${b}") | head -5
  fi

  echo "header differences:"
  diff <(zcat "${a}" | grep '^#') <(zcat "${b}" | grep '^#') | head -5
}

# Count sites only in A, only in B, and shared. Output folder: ${WORK}/isec_<sample>_<name>
count_private_sites() {
  local name=$1 a=$2 b=$3
  local dir=${WORK}/isec_${SAMPLE}_${name}

  bcftools isec -p "${dir}" "${a}" "${b}"
  echo "${name}:" \
    "only-first=$(grep -vc '^#' "${dir}/0000.vcf")" \
    "only-second=$(grep -vc '^#' "${dir}/0001.vcf")" \
    "shared=$(grep -vc '^#' "${dir}/0002.vcf")"
}

# BAMs are binary, so hash the reads without the header.
hash_bams() {
  local bam
  for bam in "${BAM_DIR}"/"${SAMPLE}"_recalibrated_*.bam; do
    echo -n "$(basename "${bam}")  "
    samtools view "${bam}" | md5sum
  done
}

main() {
  log_header
  do_module "${BIO_MODULE}"

  log_step "Compare VCFs"
  compare_vcf "${MODULE_VCF}" "${CONTAINER_VCF}"
  compare_vcf "${CONTAINER_VCF}" "${PARABRICKS_VCF}"

  log_step "Shared and private sites"
  count_private_sites module_vs_container "${MODULE_VCF}" "${CONTAINER_VCF}"
  count_private_sites container_vs_parabricks "${CONTAINER_VCF}" "${PARABRICKS_VCF}"

  log_step "BAM read hashes"
  hash_bams
}

main 2>&1 | tee "${RESULTS}"
