#!/bin/bash
# 05_efficiency.sh: CPU and memory efficiency of finished jobs.
# Not a Slurm job: seff is quick, so run it on the head node.
# seff already reports cores, wall time, CPU efficiency and memory efficiency.
# Usage: bash scripts/05_efficiency.sh JOBID [JOBID...]
set -uo pipefail

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 JOBID [JOBID...]" >&2
  exit 1
fi

for job in "$@"; do
  echo "=== job ${job}"
  seff "${job}"
done
