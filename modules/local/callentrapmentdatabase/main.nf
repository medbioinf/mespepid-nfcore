process CALL_ENTRAPMENT_DATABASE {
    label 'process_single'
    label 'fdrbench_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    path fasta
    val fold

    output:
    path "*.fasta", emit: fasta
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Convert Nextflow memory object to GB for Java
    MEM_GB=\$(( ${task.memory.toGiga()} ))

    java -Xmx\${MEM_GB}G \
        -jar /opt/fdrbench/fdrbench.jar \
        -db ${fasta} \
        -o ${fasta.baseName}-entrapment.fasta \
        -fold ${fold} \
        -level protein \
        -entrapment_label ENTRAPMENT_ \
        -entrapment_pos 0 \
        -uniprot \
        -check

    # 'Reheader' to add entrapment index to database and accession part of the header
    # and remove empty entrapment sequences (which can appear if the original sequence has many Xs)
    # The following sed command performs two operations:
    # 1. Substitutes FASTA headers to include the entrapment index in both the database and accession parts.
    #    Regex breakdown:
    #      ^>ENTRAPMENT_(.+)\\|(.+)\\|(.+)_([0-9]+)\$
    #        - Matches headers starting with '>ENTRAPMENT_' followed by three fields separated by '|', with the last field ending in '_[number]'.
    #      >ENTRAPMENT_\\4_\\1|ENTRAPMENT_\\4_\\2|\\3_\\4
    #        - Rewrites the header to include the entrapment index (\\4) in both the database and accession parts.
    # 2. Removes empty entrapment sequences (headers followed by an empty line).
    #    Control flow:
    #      \$!N;/>.*\\n\$/d;P;D
    #        - Reads two lines at a time; if a header is followed by an empty line, deletes both.

    sed -r -i \
        -e "s;^>ENTRAPMENT_(.+)\\|(.+)\\|(.+)_([0-9]+)\$;>ENTRAPMENT_\\4_\\1|ENTRAPMENT_\\4_\\2|\\3_\\4;g" \
        -e '\$!N;/>.*\\n\$/d;P;D' \
        ${fasta.baseName}-entrapment.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fdrbench: \$(java -jar /opt/fdrbench/fdrbench.jar --version 2>/dev/null || echo unknown)
    END_VERSIONS
    """
}
