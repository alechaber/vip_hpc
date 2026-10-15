#!/bin/bash
# 01_bqsr.sh: submit ApplyBQSR for one sample as its own Slurm job (Task 2a).
# Usage: bash scripts/chain/01_bqsr.sh SAMPLE
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"
source "${PROJECT_DIR}/lib/submit.sh"
require_vars GATK_TOOL APPLYBQSR_CPUS APPLYBQSR_MEM APPLYBQSR_TIME

sample=${1:?Usage: bash scripts/chain/01_bqsr.sh SAMPLE}

job=$(submit_bqsr "${sample}")
echo "bqsr job for ${sample}: ${job}"
