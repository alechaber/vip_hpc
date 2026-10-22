# Assignment 2: Scaling Workflows and Introduction to Nextflow

## Goals
- Run many samples with a for loop and with a Slurm job array
- Split ApplyBQSR and HaplotypeCaller into separate jobs and chain them
- Compare the same pipeline in WDL, Snakemake and Nextflow

## What's what
- `scripts/07_duplicate_samples.sh`: copies the Assignment 1 files into sample_01 to sample_10
- `scripts/08_loop.sh`: one job that loops over all samples
- `scripts/09_array.sh`: one job array with one task per sample
- `scripts/chain/01_bqsr.sh`: ApplyBQSR as its own job
- `scripts/chain/02_haplotypecaller.sh`: HaplotypeCaller as its own job
- `scripts/chain/03_chain.sh`: submits both with `--dependency=afterok`
- `workflows/`: WDL, Snakemake and Nextflow versions of a 3-step pipeline

## How to submit
Run from the repo root.
- `bash scripts/07_duplicate_samples.sh`
- `bash scripts/08_loop.sh`
- `bash scripts/09_array.sh`
- `bash scripts/chain/03_chain.sh sample_01`

## Logs
Logs and generated job scripts are in `$WORK/logs` and `$WORK/sbatch` on scratch, not in this repo.

# VIP HPC Assignment 1: variant calling three ways

Takes one public sample (SRR622461) through alignment, base-quality recalibration and variant
calling with the GATK module, the GATK container and NVIDIA Parabricks, then compares the
results and the resource use.

## Folder layout
```
config/config.env   all versions, paths, file names and job sizes (edit here only)
lib/lib.sh          helper functions: create_sbatch, submit_job, log_header, log_step, do_module
lib/steps.sh        the work, one function per step (step_align, step_bqsr, step_applybqsr, ...)
scripts/            numbered drivers you run; each creates and submits Slurm jobs
docs/               notes and results
```
Generated job scripts and logs live under `$WORK` (scratch), not in this repo.

## Run order
Run from the repo root. Plain `.sh` drivers run with `bash`; the `.sbatch` files they create need no `chmod`.

| Step | Command | What it does |
|:--|:--|:--|
| 1 | `bash scripts/01_download.sh` | submit the SRA download job |
| 2 | `bash scripts/02_prep.sh [DOWNLOAD_JOB]` | align + mark duplicates, then BaseRecalibrator |
| 3 | `bash scripts/03_call_variants.sh [BQSR_JOB]` | ApplyBQSR then HaplotypeCaller for module and container, plus Parabricks |
| 4 | `bash scripts/04_compare.sh` | compare VCFs and BAMs (head node, not a job) |
| 5 | `bash scripts/05_efficiency.sh JOBID...` | `seff` for each finished job (head node) |
| 6 | `bash scripts/06_sweep.sh` | HaplotypeCaller resource sweep |

Before the first run: build the reference index and dictionary, and place the known-sites file
named in `config.env` (`KNOWN_SITES`).

## Reading the logs
Each log is `$WORK/logs/<SAMPLE>_<step>_<jobid>.out`. The first lines say which sample, job and node
it belongs to, and each stage prints a `=== time | sample | stage ===` header.
GPU samples are in `<SAMPLE>_gpu_<jobid>.csv`. Generated job scripts: `$WORK/sbatch/<SAMPLE>_<step>.sbatch`.

## Output names
Everything starts with the sample name so a second sample cannot overwrite the first:
`<SAMPLE>_dedup.bam`, `<SAMPLE>_recal.table`, `<SAMPLE>_recalibrated_<tool>_<version>.bam`,
`<SAMPLE>_<tool>_<version>.vcf.gz`.

## Resources
Job sizes are set once in `config.env`. Steps read `SLURM_CPUS_PER_TASK`, and GATK takes 75% of the
job's memory with `-XX:MaxRAMPercentage`. Walltimes are short on purpose (the default is 1 hour,
and short requests start sooner).

## Start of a git repo
```
git init && git add . && git commit -m "Assignment 1 scripts"
```
Then create a repo on GitHub and push, so edits happen in one place.
