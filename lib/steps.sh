# steps.sh: the actual work, one function per step.
# Resources come from Slurm (SLURM_CPUS_PER_TASK), never typed inline.

# Java heap as a share of the job's memory limit, so there is no memory math here.
JAVA_OPTS="-XX:MaxRAMPercentage=75"

# Label used in output names, e.g. module_4.6.2.0
tool_label() {
  case $1 in
    module)     echo "module_${GATK_MODULE_VERSION}" ;;
    container)  echo "container_${GATK_VERSION}" ;;
    parabricks) echo "parabricks_${PB_VERSION}" ;;
    *) echo "unknown tool: $1" >&2; return 1 ;;
  esac
}

# Name of the recalibrated BAM for a tool.
recalibrated_bam() {
  echo "${BAM_DIR}/${SAMPLE}_recalibrated_$(tool_label "$1").bam"
}

# Fill the GATK_CMD array for the module or the container.
set_gatk_cmd() {
  case $1 in
    module)
      do_module "${GATK_MODULE}"
      GATK_CMD=(gatk)
      ;;
    container)
      # Build in node-local temp space (scratch rejects the file attributes images need).
      export APPTAINER_CACHEDIR="${CACHE_DIR}"
      APPTAINER_TMPDIR=$(mktemp -d /tmp/apptmp.XXXX)
      export APPTAINER_TMPDIR
      GATK_CMD=(singularity exec --bind "${WORK}" "${GATK_IMAGE}" gatk)
      ;;
    *) echo "unknown tool: $1" >&2; return 1 ;;
  esac
}

# ---------- Task 2: data ----------

# Download one or more accessions (default: SAMPLE). Modules load once, outside the loop.
step_download() {
  local accessions=("$@") acc
  if [ "${#accessions[@]}" -eq 0 ]; then
    accessions=("${SAMPLE}")
  fi

  do_module "${BIO_MODULE}"
  mkdir -p "${FASTQ_DIR}"
  cd "${FASTQ_DIR}"

  for acc in "${accessions[@]}"; do
    log_step "Download ${acc} from SRA (first ${SUBSAMPLE_READS} read pairs)"
    fastq-dump -X "${SUBSAMPLE_READS}" --split-files --gzip "${acc}"
  done
}

# ---------- Task 3: shared preprocessing ----------

step_align() {
  do_module "${BIO_MODULE}" "${GATK_MODULE}"
  mkdir -p "${BAM_DIR}"

  log_step "Align with bwa mem and sort"
  bwa mem -t "${SLURM_CPUS_PER_TASK}" -R "${READ_GROUP}" "${REF}" "${FASTQ_1}" "${FASTQ_2}" \
    | samtools sort -@ "${SLURM_CPUS_PER_TASK}" -o "${SORTED_BAM}" -
  samtools index "${SORTED_BAM}"

  log_step "Mark duplicates"
  gatk --java-options "${JAVA_OPTS}" MarkDuplicates \
    -I "${SORTED_BAM}" -O "${DEDUP_BAM}" -M "${DUP_METRICS}"
  samtools index "${DEDUP_BAM}"

  log_step "Check where the reads landed (use this to choose INTERVALS)"
  samtools idxstats "${DEDUP_BAM}" > "${IDXSTATS}"
}

step_bqsr() {
  do_module "${GATK_MODULE}"

  log_step "BaseRecalibrator: learn the base-quality error model"
  gatk --java-options "${JAVA_OPTS}" BaseRecalibrator \
    -R "${REF}" \
    -I "${DEDUP_BAM}" \
    --known-sites "${KNOWN_SITES}" \
    -L "${INTERVALS}" \
    -O "${RECAL_TABLE}"
}

# ---------- Task 3: ApplyBQSR and HaplotypeCaller (module or container) ----------

step_applybqsr() {
  local tool=$1
  log_step "ApplyBQSR with $(tool_label "${tool}")"
  set_gatk_cmd "${tool}"

  "${GATK_CMD[@]}" --java-options "${JAVA_OPTS}" ApplyBQSR \
    -R "${REF}" \
    -I "${DEDUP_BAM}" \
    --bqsr-recal-file "${RECAL_TABLE}" \
    -L "${INTERVALS}" \
    -O "$(recalibrated_bam "${tool}")"
}

step_haplotypecaller() {
  local tool=$1
  log_step "HaplotypeCaller with $(tool_label "${tool}")"
  set_gatk_cmd "${tool}"
  mkdir -p "${VCF_DIR}"

  "${GATK_CMD[@]}" --java-options "${JAVA_OPTS}" HaplotypeCaller \
    -R "${REF}" \
    -I "$(recalibrated_bam "${tool}")" \
    -L "${INTERVALS}" \
    --native-pair-hmm-threads "${SLURM_CPUS_PER_TASK}" \
    -O "${VCF_DIR}/${SAMPLE}_$(tool_label "${tool}").vcf.gz"
}

# ---------- Task 3c: Parabricks (both steps in one GPU job) ----------

start_gpu_log() {
  nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv -l 5 > "$1" &
  GPU_LOG_PID=$!
}

# Stop the logger. It may already be gone, which must not fail the job.
stop_gpu_log() {
  if [ -n "${GPU_LOG_PID:-}" ]; then
    kill "${GPU_LOG_PID}" 2>/dev/null || true
  fi
}

step_parabricks() {
  local pbrun=(singularity exec --nv --bind "${WORK}" "${PB_SIF}" pbrun)
  mkdir -p "${VCF_DIR}"
  start_gpu_log "${LOG_DIR}/${SAMPLE}_gpu_${SLURM_JOB_ID}.csv"

  log_step "Parabricks applybqsr"
  "${pbrun[@]}" applybqsr \
    --ref "${REF}" \
    --in-bam "${DEDUP_BAM}" \
    --in-recal-file "${RECAL_TABLE}" \
    --interval "${INTERVALS}" \
    --out-bam "$(recalibrated_bam parabricks)"

  log_step "Parabricks haplotypecaller"
  "${pbrun[@]}" haplotypecaller \
    --ref "${REF}" \
    --in-bam "$(recalibrated_bam parabricks)" \
    --interval "${INTERVALS}" \
    --out-variants "${VCF_DIR}/${SAMPLE}_$(tool_label parabricks).vcf.gz"

  stop_gpu_log
}

# ---------- Task 6: resource sweep ----------

step_sweep_haplotypecaller() {
  local out=${SWEEP_DIR}/${SAMPLE}_haplotypecaller_${SLURM_CPUS_PER_TASK}c_${SLURM_MEM_PER_NODE}M.vcf.gz
  log_step "Sweep: HaplotypeCaller (container) writing ${out}"
  set_gatk_cmd container
  mkdir -p "${SWEEP_DIR}"

  "${GATK_CMD[@]}" --java-options "${JAVA_OPTS}" HaplotypeCaller \
    -R "${REF}" \
    -I "$(recalibrated_bam container)" \
    -L "${INTERVALS}" \
    --native-pair-hmm-threads "${SLURM_CPUS_PER_TASK}" \
    -O "${out}"
}

# ---------- Assignment 2: many samples ----------

# True when the current sample's final VCF and its index exist. This is the checkpoint.
sample_is_done() {
  local vcf=${VCF_DIR}/${SAMPLE}_$(tool_label "${GATK_TOOL}").vcf.gz
  [ -s "${vcf}" ] && [ -s "${vcf}.tbi" ]
}

# ApplyBQSR then HaplotypeCaller for the current sample.
# Each step is checked by hand: "set -e" is switched off inside a function
# that is called from an if test, so a failure would not stop the second step.
run_sample() {
  step_applybqsr "${GATK_TOOL}" || return 1
  step_haplotypecaller "${GATK_TOOL}" || return 1
}

# Task 1b: run every sample in SAMPLE_LIST one after another in this single job.
# A failed sample is recorded and the loop moves on; the job fails at the end if any failed.
step_loop_samples() {
  local samples=() name failed=()
  mapfile -t samples < "${SAMPLE_LIST}"   # not "while read": gatk would eat the list from stdin

  echo "Samples in this job (${#samples[@]}): ${samples[*]}"

  for name in "${samples[@]}"; do
    set_sample "${name}"
    log_step "sample ${name}: start"

    if sample_is_done; then
      log_step "sample ${name}: already done, skipping"
      continue
    fi

    if run_sample; then
      log_step "sample ${name}: finished"
    else
      log_step "sample ${name}: FAILED"
      failed+=("${name}")
    fi
  done

  log_step "loop summary: ${#failed[@]} failed out of ${#samples[@]}"
  if [ "${#failed[@]}" -gt 0 ]; then
    echo "Failed samples: ${failed[*]}"
    return 1
  fi
}
