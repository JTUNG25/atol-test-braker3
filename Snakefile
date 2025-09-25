#!/usr/bin/env python3
def get_collect_input(wildcards):
    return query_genome[wildcards.genome]


###########
# GLOBALS #
###########

# containers
bbmap = "docker://quay.io/biocontainers/bbmap:39.01--h92535d8_1"
braker3 = "docker://teambraker/braker3:v3.0.7.1"

# Braker3 data
db_path = "data/braker3_db"

# config
query_genome = {
    "A_magna": {"busco_seed_species": "chicken", "busco_db": "passeriformes_odb10"},
    "E_pictum": {"busco_seed_species": "chicken", "busco_db": "passeriformes_odb10"},
    "R_gram": {
        "busco_seed_species": "botrytis_cinerea",
        "busco_db": "helotiales_odb10",
    },
    "X_john": {"busco_seed_species": "maize", "busco_db": "liliopsida_odb10"},
    "T_triandra": {"busco_seed_species": "maize", "busco_db": "poales_odb10"},
    "H_bino": {"busco_seed_species": "chicken", "busco_db": "sauropsida_odb10"},
    "P_vit": {"busco_seed_species": "chicken", "busco_db": "sauropsida_odb10"},
}

#########
# RULES #
#########


rule target:
    input:
        expand(
            "results/{genome}/funannotate/braker3_results/annot.gff3",
            genome=genome_config.keys(),
        ),


rule collect_output:
    input:
        Path(outdir, "braker", "{outfile}"),
    output:
        Path(outdir, "{outfile}"),
    threads: 1
    shell:
        "mv {input} {output}"


# braker3
# n.b. you have to cd to wd, otherwise braker overwrites the input file
rule braker3:
    input:
        fasta=("results/{genome}/reformat/genome.fa"),
        db=db_path,
    output:
        expand(
            "results/{genome}/funannotate/braker3_results/annot.gff3",
            genome=genome_config.keys(),
        ),
    params:
        wd=lambda wildcards, output: Path(output.gff).parent.parent.resolve(),
    log:
        "logs/braker3_results/{genome}.log",
    benchmark:
        Path(benchdir, "braker3.txt").resolve()
    threads: lambda wildcards, attempt: 20 * attempt
    resources:
        time=lambda wildcards, attempt: 10080 * attempt,
        mem_mb=lambda wildcards, attempt: 24e3 * attempt,
    container:
        braker3
    shell:
        "cd {params.wd} || exit 1 && "
        "braker.pl "
        "--gff3 "
        "--threads {threads} "
        "{params.proteins} "
        "{params.species} "
        "&> {log}"


#################
# collect input #
#################


# Make sure there are mapped reads in the bamfile. If there are no mapped reads,
# braker3 will try to run GeneMark-ETP, which will crash.


# n.b. whitespace in the header breaks braker
rule reformat:
    input:
        "data/genomes/{genome}.fasta",
    output:
        temp("results/{genome}/reformat/genome.fasta"),
    params:
        ignorejunk=lambda wildcards: "t",
    log:
        "logs/reformat/{genome}.log",
    container:
        bbmap
    shell:
        "reformat.sh "
        "fixheaders=t "
        "in={input} "
        "out={output} "
        "2>{log}"
