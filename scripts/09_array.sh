#!/bin/bash
# 09_array.sh: Task 1c. One Slurm job array: task N runs ApplyBQSR and HaplotypeCaller
# for line N of SAMPLE_LIST. All samples run at the same time.
# Usage: bash scripts/09_array.sh
#        GATK_TOOL=container bash scripts/09_array.sh     (use the container instead)
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"
require_vars SAMPLE_LIST GATK_TOOL N_SAMPLES ARRAY_THROTTLE ARRAY_CPUS ARRAY_MEM ARRAY_TIME

# Names the job and script after the batch. Array logs end in _<arrayjob>_<task>.out.
JOB_LABEL="${N_SAMPLES}_samples"
LOG_ID_PATTERN='%A_%a'

array_line="#SBATCH --array=1-${N_SAMPLES}%${ARRAY_THROTTLE}"

job=$(create_and_submit array "${ARRAY_CPUS}" "${ARRAY_MEM}" "${ARRAY_TIME}" \
  step_array_sample "" "${array_line}")
echo "array job: ${job}"
