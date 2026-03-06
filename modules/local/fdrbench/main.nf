/*
 * Create an entrapment database for FDR assessment
 */
process FDRBENCH {
    tag "${meta.id}"
    label 'process_single'

    // TODO Need to create a conda and singularity package...
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE'
        : 'quay.io/medbioinf/fdrbench-nightly:146f77'}"

    input:
    tuple val(meta), path(fasta)
    val fold

    output:
    tuple val(meta), path("*-entrapment.fasta"), emit: entrapment_fasta
    tuple val("${task.process}"), val('fdrbench'), val('nightly:146f77'), topic: versions, emit: versions_fdrbench
    tuple val("${task.process}"), val('java'), eval('java -version 2>&1 | head -1'), topic: versions, emit: versions_java

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def avail_mem = 8192
    if (!task.memory) {
        log.info('[FDRBench] Available memory not known - defaulting to 4GB. Specify process memory requirements to change this.')
    }
    else {
        avail_mem = (task.memory.mega * 0.9).intValue()
    }

    """
    java -Xmx${avail_mem}M \\
        ${args} \\
        -jar /opt/fdrbench/fdrbench.jar \\
            -db ${fasta} \\
            -o ${prefix}-entrapment.fasta \\
            -fold ${fold} \\
            -level protein \\
            -entrapment_label ENTRAPMENT_ \\
            -entrapment_pos 0 \\
            -uniprot -check

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

    sed -r -i \\
        -e "s;^>ENTRAPMENT_(.+)\\|(.+)\\|(.+)_([0-9]+)\$;>ENTRAPMENT_\\4_\\1|ENTRAPMENT_\\4_\\2|\\3_\\4;g" \\
        -e '\$!N;/>.*\\n\$/d;P;D' \\
        ${prefix}-entrapment.fasta
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}

    touch ${prefix}-entrapment.fasta
    """
}
