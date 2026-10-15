#!/bin/bash
# 08_loop.sh: Task 1b. One Slurm job runs ApplyBQSR and HaplotypeCaller for every
# sample in SAMPLE_LIST, one after another, inside a for loop.
# Usage: bash scripts/08_loop.sh
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"
require_vars SAMPLE_LIST GATK_TOOL LOOP_CPUS LOOP_MEM LOOP_TIME N_SAMPLES

# Names the job, script and log after the batch instead of one sample.
JOB_LABEL="${N_SAMPLES}_samples"

job=$(create_and_submit loop "${LOOP_CPUS}" "${LOOP_MEM}" "${LOOP_TIME}" step_loop_samples)
echo "loop job: ${job}"
