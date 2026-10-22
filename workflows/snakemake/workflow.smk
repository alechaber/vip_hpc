# workflow.smk: index > ApplyBQSR > HaplotypeCaller for many samples (Task 3, Snakemake).
# Not executed. Snakemake works backwards: rule all asks for the final VCFs,
# and each rule's input file names tell Snakemake which rule to run before it.

configfile: "config.yaml"

SAMPLES = config["samples"]
OUT = config["out_dir"]
GATK_IMAGE = "docker://broadinstitute/gatk:" + config["gatk_version"]


rule all:
    input:
        expand(OUT + "/{sample}_haplotypecaller.vcf.gz", sample=SAMPLES)


rule index_bam:
    input:
        bam=config["bam_dir"] + "/{sample}_dedup.bam"
    output:
        bai=config["bam_dir"] + "/{sample}_dedup.bam.bai"
    threads: 2
    container: config["samtools_image"]
    log: OUT + "/logs/{sample}_index_bam.log"
    shell:
        "samtools index -@ {threads} {input.bam} 2> {log}"


rule apply_bqsr:
    input:
        bam=config["bam_dir"] + "/{sample}_dedup.bam",
        bai=config["bam_dir"] + "/{sample}_dedup.bam.bai",
        table=config["bam_dir"] + "/{sample}_recal.table",
        ref=config["ref_fasta"]
    output:
        bam=OUT + "/{sample}_recalibrated.bam"
    threads: config["bqsr_threads"]
    resources:
        mem_mb=config["bqsr_memory_mb"]
    container: GATK_IMAGE
    log: OUT + "/logs/{sample}_apply_bqsr.log"
    shell:
        """
        gatk --java-options "-XX:MaxRAMPercentage=75" ApplyBQSR \
            -R {input.ref} \
            -I {input.bam} \
            --bqsr-recal-file {input.table} \
            -O {output.bam} 2> {log}
        """


rule haplotypecaller:
    input:
        bam=OUT + "/{sample}_recalibrated.bam",
        ref=config["ref_fasta"]
    output:
        vcf=OUT + "/{sample}_haplotypecaller.vcf.gz"
    threads: config["haplotypecaller_threads"]
    resources:
        mem_mb=config["haplotypecaller_memory_mb"]
    container: GATK_IMAGE
    log: OUT + "/logs/{sample}_haplotypecaller.log"
    shell:
        """
        gatk --java-options "-XX:MaxRAMPercentage=75" HaplotypeCaller \
            -R {input.ref} \
            -I {input.bam} \
            --native-pair-hmm-threads {threads} \
            -O {output.vcf} 2> {log}
        """
