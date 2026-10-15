#!/bin/bash
# 01_download.sh: submit the data download as a Slurm job (4 threads is the data-transfer limit).
# Usage: bash scripts/01_download.sh [ACCESSION...]     default: SAMPLE from config.env
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"

mkdir -p "${WORK}"

job=$(create_and_submit download "${DOWNLOAD_CPUS}" "${DOWNLOAD_MEM}" "${DOWNLOAD_TIME}" \
  "step_download $*")
echo "download job: ${job}"
