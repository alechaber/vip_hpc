#!/bin/bash
# 03_call_variants.sh: ApplyBQSR then HaplotypeCaller for each tool (HaplotypeCaller waits for ApplyBQSR).
# Usage: bash scripts/03_call_variants.sh [BQSR_JOB_ID]     (optional: wait for the BQSR job first)
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"

prep_job=${1:-}

# Submit the ApplyBQSR -> HaplotypeCaller chain for one GATK tool (module or container).
submit_gatk_chain() {
  local tool=$1 applybqsr_job haplotypecaller_job

  applybqsr_job=$(create_and_submit "applybqsr_${tool}" \
    "${APPLYBQSR_CPUS}" "${APPLYBQSR_MEM}" "${APPLYBQSR_TIME}" \
    "step_applybqsr ${tool}" "${prep_job}")

  haplotypecaller_job=$(create_and_submit "haplotypecaller_${tool}" \
    "${HAPLOTYPECALLER_CPUS}" "${HAPLOTYPECALLER_MEM}" "${HAPLOTYPECALLER_TIME}" \
    "step_haplotypecaller ${tool}" "${applybqsr_job}")

  echo "${tool}: applybqsr=${applybqsr_job} haplotypecaller=${haplotypecaller_job}"
}

# Submit the single GPU job for Parabricks.
submit_parabricks() {
  local gpu_lines="#SBATCH --partition=${GPU_PARTITION}"$'\n'"#SBATCH --gres=gpu:1"
  local job

  job=$(create_and_submit parabricks "${PB_CPUS}" "${PB_MEM}" "${PB_TIME}" \
    step_parabricks "${prep_job}" "${gpu_lines}")

  echo "parabricks: ${job}"
}

submit_gatk_chain module
submit_gatk_chain container
submit_parabricks
