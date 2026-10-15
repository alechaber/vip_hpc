# submit.sh: create and submit one job for one sample. Each function prints the job ID.
# Usage: submit_bqsr SAMPLE [JOB_ID_TO_WAIT_FOR]

submit_bqsr() {
  local sample=$1 dependency=${2:-}
  set_sample "${sample}"

  create_and_submit bqsr \
    "${APPLYBQSR_CPUS}" "${APPLYBQSR_MEM}" "${APPLYBQSR_TIME}" \
    "step_applybqsr ${GATK_TOOL}" "${dependency}"
}

submit_haplotypecaller() {
  local sample=$1 dependency=${2:-}
  set_sample "${sample}"

  create_and_submit haplotypecaller \
    "${HAPLOTYPECALLER_CPUS}" "${HAPLOTYPECALLER_MEM}" "${HAPLOTYPECALLER_TIME}" \
    "step_haplotypecaller ${GATK_TOOL}" "${dependency}"
}
