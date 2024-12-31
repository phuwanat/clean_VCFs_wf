version 1.0

workflow clean_VCFs {

	meta {
	author: "Phuwanat Sakornsakolpat"
		email: "phuwanat.sak@mahidol.edu"
		description: "Clean VCF (remove star, split multi-allelic, left-align and normalization using fasta ref)"
	}

	 input {
		File vcf_file
	}

	call run_filtering { 
			input: vcf = vcf_file
	}

	output {
		File cleaned_vcf = run_filtering.out_file
		File cleaned_tbi = run_filtering.out_file_tbi
	}

}

task run_filtering {
	input {
		File vcf
		Int memSizeGB = 8
		Int threadCount = 2
		Int diskSizeGB = 8*round(size(vcf, "GB")) + 20
	String out_name = basename(vcf, ".vcf.gz")
	String fasta_ref = "gs://gcp-public-data--broad-references/hg38/v0/Homo_sapiens_assembly38.fasta"
	}
	
	command <<<
	zcat ~{vcf} | awk '($4 != "*" && $5 != "*")' > ~{out_name}.removestared.vcf
	bgzip ~{out_name}.removestared.vcf
	tabix -p vcf ~{out_name}.removestared.vcf.gz
	
	bcftools norm -m -both --fasta-ref ~{fasta_ref} -Oz -o ~{out_name}.cleaned.vcf.gz ~{out_name}.removestared.vcf.gz
	tabix -p vcf ~{out_name}.cleaned.vcf.gz
	>>>

	output {
		File out_file = select_first(glob("*.cleaned.vcf.gz"))
		File out_file_tbi = select_first(glob("*.cleaned.vcf.gz.tbi"))
	}

	runtime {
		memory: memSizeGB + " GB"
		cpu: threadCount
		disks: "local-disk " + diskSizeGB + " SSD"
		docker: "quay.io/biocontainers/bcftools@sha256:f3a74a67de12dc22094e299fbb3bcd172eb81cc6d3e25f4b13762e8f9a9e80aa"   # digest: quay.io/biocontainers/bcftools:1.16--hfe4b78e_1
		preemptible: 1
	}

}