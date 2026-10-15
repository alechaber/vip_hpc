#!/bin/bash
# 02_prep.sh: submit alignment, then BaseRecalibrator once alignment succeeds.
# Usage: bash scripts/02_prep.sh [DOWNLOAD_JOB_ID]     (optional: wait for the download job first)
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"
require_vars SAMPLE REF KNOWN_SITES

download_job=${1:-}

align_job=$(create_and_submit align "${PREP_CPUS}" "${PREP_MEM}" "${PREP_TIME}" \
  step_align "${download_job}")
echo "align job: ${align_job}"

bqsr_job=$(create_and_submit bqsr "${BQSR_CPUS}" "${BQSR_MEM}" "${BQSR_TIME}" \
  step_bqsr "${align_job}")
echo "bqsr job: ${bqsr_job}"
