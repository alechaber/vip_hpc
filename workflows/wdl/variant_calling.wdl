version 1.0

# variant_calling.wdl: index > ApplyBQSR > HaplotypeCaller for one sample (Task 3, WDL).
# Not executed. Resource sizes come from the seff results in Task 2a.

workflow variant_calling {
  input {
    String sample
    File dedup_bam
    File recal_table
    File ref_fasta
    File ref_fai
    File ref_dict

    String gatk_image = "broadinstitute/gatk:4.7.0.0"
    String samtools_image = "quay.io/biocontainers/samtools:1.20--h50ea8bc_0"

    Int bqsr_cpus = 2
    Int haplotypecaller_cpus = 4
    String bqsr_memory = "6 GB"
    String haplotypecaller_memory = "8 GB"
  }

  call index_bam {
    input:
      sample = sample,
      bam = dedup_bam,
      image = samtools_image
  }

  call apply_bqsr {
    input:
      sample = sample,
      bam = index_bam.indexed_bam,
      bai = index_bam.indexed_bai,
      recal_table = recal_table,
      ref_fasta = ref_fasta,
      ref_fai = ref_fai,
      ref_dict = ref_dict,
      image = gatk_image,
      cpus = bqsr_cpus,
      memory = bqsr_memory
  }

  call haplotypecaller {
    input:
      sample = sample,
      bam = apply_bqsr.recalibrated_bam,
      bai = apply_bqsr.recalibrated_bai,
      ref_fasta = ref_fasta,
      ref_fai = ref_fai,
      ref_dict = ref_dict,
      image = gatk_image,
      cpus = haplotypecaller_cpus,
      memory = haplotypecaller_memory
  }

  output {
    File vcf = haplotypecaller.vcf
  }
}

task index_bam {
  input {
    String sample
    File bam
    String image
  }

  command <<<
    cp ~{bam} ~{sample}_dedup.bam
    samtools index ~{sample}_dedup.bam
  >>>

  output {
    File indexed_bam = "~{sample}_dedup.bam"
    File indexed_bai = "~{sample}_dedup.bam.bai"
  }

  runtime {
    docker: image
    cpu: 2
    memory: "2 GB"
  }
}

task apply_bqsr {
  input {
    String sample
    File bam
    File bai
    File recal_table
    File ref_fasta
    File ref_fai
    File ref_dict
    String image
    Int cpus
    String memory
  }

  command <<<
    gatk --java-options "-XX:MaxRAMPercentage=75" ApplyBQSR \
      -R ~{ref_fasta} \
      -I ~{bam} \
      --bqsr-recal-file ~{recal_table} \
      -O ~{sample}_recalibrated.bam
  >>>

  output {
    File recalibrated_bam = "~{sample}_recalibrated.bam"
    File recalibrated_bai = "~{sample}_recalibrated.bai"
  }

  runtime {
    docker: image
    cpu: cpus
    memory: memory
  }
}

task haplotypecaller {
  input {
    String sample
    File bam
    File bai
    File ref_fasta
    File ref_fai
    File ref_dict
    String image
    Int cpus
    String memory
  }

  command <<<
    gatk --java-options "-XX:MaxRAMPercentage=75" HaplotypeCaller \
      -R ~{ref_fasta} \
      -I ~{bam} \
      --native-pair-hmm-threads ~{cpus} \
      -O ~{sample}_haplotypecaller.vcf.gz
  >>>

  output {
    File vcf = "~{sample}_haplotypecaller.vcf.gz"
    File tbi = "~{sample}_haplotypecaller.vcf.gz.tbi"
  }

  runtime {
    docker: image
    cpu: cpus
    memory: memory
  }
}
