#!/bin/bash
# 06_sweep.sh: HaplotypeCaller (container) at several core/memory sizes, to study efficiency.
# Start high to see the ceiling, then step down (the first row is deliberately large).
# 1-core jobs use 2 CPUs because Slurm hands out CPUs in pairs.
# Usage: bash scripts/06_sweep.sh     (edit SIZES to change the grid)
set -euo pipefail
HERE="$(dirname "$(readlink -f "$0")")"
source "${HERE}/../config/config.env"
source "${PROJECT_DIR}/lib/lib.sh"

# "cores:memory" pairs
SIZES=(
  "16:16G"
  "8:6G"
  "4:6G"
  "2:6G"
  "4:4G"
  "4:3G"
  "2:2G"
)

for size in "${SIZES[@]}"; do
  cores=${size%%:*}
  mem=${size##*:}
  job=$(create_and_submit "sweep_${cores}c_${mem}" "${cores}" "${mem}" "${SWEEP_TIME}" \
    step_sweep_haplotypecaller)
  echo "sweep ${cores} cores / ${mem}: job ${job}"
done
