// main.nf: index > ApplyBQSR > HaplotypeCaller for many samples (Task 3, Nextflow).
// Not executed. Processes are the steps; the workflow block at the bottom wires them with channels.

nextflow.enable.dsl = 2

process INDEX_BAM {
    tag "${sample}"

    input:
    tuple val(sample), path(bam), path(recal_table)

    output:
    tuple val(sample), path(bam), path("${bam}.bai"), path(recal_table)

    script:
    """
    samtools index -@ ${task.cpus} ${bam}
    """
}

process APPLY_BQSR {
    tag "${sample}"
    publishDir "${params.outdir}/bam", mode: 'copy'

    input:
    tuple val(sample), path(bam), path(bai), path(recal_table)
    tuple path(ref_fasta), path(ref_fai), path(ref_dict)

    output:
    tuple val(sample), path("${sample}_recalibrated.bam"), path("${sample}_recalibrated.bai")

    script:
    """
    gatk --java-options "-XX:MaxRAMPercentage=75" ApplyBQSR \\
        -R ${ref_fasta} \\
        -I ${bam} \\
        --bqsr-recal-file ${recal_table} \\
        -O ${sample}_recalibrated.bam
    """
}

process HAPLOTYPECALLER {
    tag "${sample}"
    publishDir "${params.outdir}/vcf", mode: 'copy'

    input:
    tuple val(sample), path(bam), path(bai)
    tuple path(ref_fasta), path(ref_fai), path(ref_dict)

    output:
    tuple val(sample), path("${sample}_haplotypecaller.vcf.gz"), path("${sample}_haplotypecaller.vcf.gz.tbi")

    script:
    """
    gatk --java-options "-XX:MaxRAMPercentage=75" HaplotypeCaller \\
        -R ${ref_fasta} \\
        -I ${bam} \\
        --native-pair-hmm-threads ${task.cpus} \\
        -O ${sample}_haplotypecaller.vcf.gz
    """
}

workflow {
    samples = Channel
        .fromPath(params.samplesheet)
        .splitCsv(header: true)
        .map { row -> tuple(row.sample, file(row.bam), file(row.recal_table)) }

    ref = Channel.value(
        tuple(file(params.ref_fasta), file("${params.ref_fasta}.fai"), file(params.ref_dict))
    )

    INDEX_BAM(samples)
    APPLY_BQSR(INDEX_BAM.out, ref)
    HAPLOTYPECALLER(APPLY_BQSR.out, ref)
}
