version 1.0

struct RuntimeAttr {
  Float? mem_gb
  Int? cpu_cores
  Int? disk_gb
  Int? boot_disk_gb
  Int? preemptible_tries
  Int? max_retries
}

workflow AnnotateQC {
  input {
    File cnv_annotations
    String docker
    RuntimeAttr? runtime_attr
  }

  call qc {
    input:
      # https://github.com/talkowski-lab/gCNV-QC-Update.git
      docker = docker,
      cnv_annotations = cnv_annotations,
      runtime_attr_override = runtime_attr
  }

  output {
    File annotations_with_qc = qc.annotations_with_qc
  }
}

task qc {
  input {
    File cnv_annotations
    String docker
    RuntimeAttr? runtime_attr_override
  }

  String annotation_name = basename(cnv_annotations, ".bed")

  RuntimeAttr default_attr = object {
    mem_gb: 16,
    cpu_cores: 1,
    disk_gb: 32,
    boot_disk_gb: 10,
    preemptible_tries: 1,
    max_retries: 1
  }
  RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])

  command <<<
    gcnv_qc.R ~{cnv_annotations} ~{annotation_name}_with_qc.bed
  >>>

  output {
      File annotations_with_qc = "~{annotation_name}_with_qc.bed"
  }

  runtime {
    docker: docker
    cpu: select_first([runtime_attr.cpu_cores, default_attr.cpu_cores])
    memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
    disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
    bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.disk_gb])
    preemptible: select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
    maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
  }
}
