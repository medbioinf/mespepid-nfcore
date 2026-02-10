process MSGFPLUS_MERGE_PSMS {
    tag "$meta.id"
    label 'process_low'
    label 'python_image'
    
    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"
    
    input:
    tuple val(meta), path(psm_tsvs)

    output:
    tuple val(meta), path("${meta.id}.mzid.psm_utils.tsv"), emit: merged_psm
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    merge_chunked_psm_files.py \\
        --org_filebase ${meta.id} \\
        --out_filename ${meta.id}.mzid.psm_utils.tsv \\
        --files ${psm_tsvs} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.mzid.psm_utils.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
