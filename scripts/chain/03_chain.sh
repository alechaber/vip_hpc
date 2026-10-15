#!/bin/bash
# 03_chain.sh: submit ApplyBQSR, then HaplotypeCaller that starts only after it succeeds (Task 2b).
# The script captures the first job ID and passes it to --dependency=afterok.
# Usage: bash scripts/chain/03_chain.sh SAMPLE
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"
source "${PROJECT_DIR}/lib/submit.sh"
require_vars GATK_TOOL APPLYBQSR_CPUS APPLYBQSR_MEM APPLYBQSR_TIME
require_vars HAPLOTYPECALLER_CPUS HAPLOTYPECALLER_MEM HAPLOTYPECALLER_TIME

sample=${1:?Usage: bash scripts/chain/03_chain.sh SAMPLE}

bqsr_job=$(submit_bqsr "${sample}")
haplotypecaller_job=$(submit_haplotypecaller "${sample}" "${bqsr_job}")

echo "${sample}: bqsr=${bqsr_job} then haplotypecaller=${haplotypecaller_job} (afterok)"
