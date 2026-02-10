process MSGFPLUS_SPLIT_FASTA {
    tag "$fasta.baseName"
    label 'process_low'
    label 'python_image'
    
    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"
        
    input:
    tuple path(fasta), val(splits)

    output:
    path "${fasta.baseName}-split*.fasta", emit: fasta_parts
    path "versions.yml"                  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    
    """
    split_fasta.py \\
        -in_file ${fasta} \\
        -out_file_base ${fasta.baseName}-split \\
        -splits ${splits} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    """
    touch ${fasta.baseName}-split-1.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
