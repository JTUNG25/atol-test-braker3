#!/usr/bin/env python3

##########
# GLOBALS #
###########

# containers
bbmap = "docker://quay.io/biocontainers/bbmap:39.01--h92535d8_1"
braker3 = "docker://teambraker/braker3:v3.0.7.1"

# config
query_genome = [
    "E_pictum",
    "R_gram",
]

#########
# RULES #
#########


rule target:
    input:
        expand(
            "results/{genome}/braker3/{genome}_rnaseq.{ext}",
            genome=query_genome,
            ext=["gff3", "gtf", "gtf.gz"],
        ),


rule compress_braker_output:
    input:
        gtf="results/{genome}/braker3/{genome}_rnaseq.gtf",
    output:
        gtf_gz="results/{genome}/braker3/{genome}_rnaseq.gtf.gz",
    container:
        braker3
    shell:
        "gzip -k {input.gtf}"


rule collect_braker_output:
    input:
        gff="results/{genome}/braker3/rnaseq_evidence/braker/braker.gff3",
        gtf="results/{genome}/braker3/rnaseq_evidence/braker/braker.gtf",
    output:
        gff="results/{genome}/braker3/{genome}_rnaseq.gff3",
        gtf="results/{genome}/braker3/{genome}_rnaseq.gtf",
    container:
        braker3
    shell:
        "cp {input.gff} {output.gff} ; "
        "cp {input.gtf} {output.gtf} "


# braker3
# n.b. you have to cd to wd, otherwise braker overwrites the input file
rule braker3:
    input:
        fasta="results/{genome}/reformat/genome.fasta",
        bam="data/hisat2/{genome}.bam",
    output:
        gff="results/{genome}/braker3/rnaseq_evidence/braker/braker.gff3",
        gtf="results/{genome}/braker3/rnaseq_evidence/braker/braker.gtf",
    params:
        wd=lambda wildcards, output: Path(output.gff).parent.parent.resolve(),
        fasta=lambda wildcards, input: Path(input.fasta).resolve(),
        bam=lambda wildcards, input: Path(input.bam).resolve(),
    log:
        Path("logs/braker3/{genome}_rnaseq.log").resolve(),
    benchmark:
        Path("logs/braker3/benchmark/{genome}_rnaseq.txt").resolve()
    threads: 32
    resources:
        runtime=int(2 * 24 * 60),
        mem_mb=int(256e3),
    container:
        braker3
    shell:
        "cd {params.wd} || exit 1 && "
        "braker.pl "
        "--gff3 "
        "--threads {threads} "
        "--species={wildcards.genome} "
        "--genome={params.fasta} "
        "--bam={params.bam} "
        "&> {log}"


# n.b. whitespace in the header breaks braker
rule reformat:
    input:
        "data/genomes/{genome}.fasta",
    output:
        temp("results/{genome}/reformat/genome.fasta"),
    log:
        "logs/reformat/{genome}.log",
    resources:
        runtime=10,
        mem_mb=int(8e3),
    container:
        bbmap
    shell:
        "reformat.sh "
        "fixheaders=t "
        "trimreaddescription=t "
        "-Xmx{resources.mem_mb}m "
        "in={input} "
        "out={output} "
        "2>{log}"
