version 1.1

workflow AnnotateQC {
    input {
	File annotations

	String docker

	Int? disk_space_gb
	Int? machine_mem_gb
    }

    call qc {
	input:
	    # https://github.com/talkowski-lab/gCNV-QC-Update.git
	    docker = docker,
	    annotations = annotations,
	    disk_space_gb = disk_space_gb,
	    machine_mem_gb = machine_mem_gb	
    }

    output {
	File annotations_with_qc = qc.annotations_with_qc
    }
}

task qc {
    input {
	File annotations
	String docker
	Int? disk_space_gb
	Int? machine_mem_gb
    }

    Int cpu = 1
    String disks = if defined(disk_space_gb) then "~{disk_space_gb} GB" else "32 GB"
    String memory = if defined(machine_mem_gb) then "~{machine_mem_gb} GB" else "16 GB"
    
    command <<<
	Rscript /scripts/gcnv_qc.R ~{annotations} ~{annotations}.tmp
	mv ~{annotations}.tmp ~{annotations}
    >>>

    output {
	File annotations_with_qc = annotations
    }

    runtime {
	container: docker
	cpu: cpu
	memory: memory
	disks: disks
    }
}
