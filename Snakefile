#!/usr/bin/env python3

##########
# GLOBALS #
###########

# containers
bbmap = "docker://quay.io/biocontainers/bbmap:39.01--h92535d8_1"
braker3 = "docker://teambraker/braker3:v3.0.7.1"

# config
query_genome = [
    "A_magna",
    "E_pictum",
    "R_gram",
    "X_john",
    "T_triandra",
    "H_bino",
    "P_vit",
    "P_halo",
    "N_erebi",
    "N_cryptoides",
]

#########
# RULES #
#########


rule target:
    input:
        expand(
            "results/{genome}/braker3/{genome}.{ext}",
            genome=query_genome,
            ext=["gff3", "gtf"],
        ),


rule collect_braker_output:
    input:
        gff="results/{genome}/braker3/braker/braker.gff3",
        gtf="results/{genome}/braker3/braker/braker.gtf",
    output:
        gff="results/{genome}/braker3/{genome}.gff3",
        gtf="results/{genome}/braker3/{genome}.gtf",
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
    output:
        gff="results/{genome}/braker3/braker/braker.gff3",
        gtf="results/{genome}/braker3/braker/braker.gtf",
    params:
        wd=lambda wildcards, output: Path(output.gff).parent.parent.resolve(),
        fasta=lambda wildcards, input: Path(input.fasta).resolve(),
    log:
        Path("logs/braker3/{genome}.log").resolve(),
    benchmark:
        Path("logs/braker3/benchmark/{genome}.txt").resolve()
    threads: 32
    resources:
        runtime=int(24 * 60),
        mem_mb=int(64e3),
    container:
        braker3
    shell:
        "cd {params.wd} || exit 1 && "
        "braker.pl "
        "--gff3 "
        "--threads {threads} "
        "--species={wildcards.genome} "
        "--genome={params.fasta}"
        "&> {log}"


# n.b. whitespace in the header breaks braker
rule reformat:
    input:
        "data/genomes/{genome}.fasta",
    output:
        temp("results/{genome}/reformat/genome.fasta"),
    log:
        "logs/reformat/{genome}.log",
    container:
        bbmap
    shell:
        "reformat.sh "
        "fixheaders=t "
        "trimreaddescription=t "
        "in={input} "
        "out={output} "
        "2>{log}"
