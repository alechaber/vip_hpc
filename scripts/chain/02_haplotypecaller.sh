#!/bin/bash
# 02_haplotypecaller.sh: submit HaplotypeCaller for one sample as its own Slurm job (Task 2a).
# With a job ID, the job waits until that job finishes successfully (Task 2b, manual version).
# Usage: bash scripts/chain/02_haplotypecaller.sh SAMPLE [BQSR_JOB_ID]
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"
source "${PROJECT_DIR}/lib/submit.sh"
require_vars GATK_TOOL HAPLOTYPECALLER_CPUS HAPLOTYPECALLER_MEM HAPLOTYPECALLER_TIME

sample=${1:?Usage: bash scripts/chain/02_haplotypecaller.sh SAMPLE [BQSR_JOB_ID]}
bqsr_job=${2:-}

job=$(submit_haplotypecaller "${sample}" "${bqsr_job}")
echo "haplotypecaller job for ${sample}: ${job}"
