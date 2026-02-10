// Original file: mspepid/src/postprocessing/convert_and_enhance_psm_tsv.nf (enhance_psms_and_create_pin - adjust_psm_list.py part)
process ADJUST_PSM_LIST {
    tag "$meta.id"
    label 'process_low'
    label 'python_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(psm_utils_tsv), val(searchengine)

    output:
    tuple val(meta), path("*.adjusted.tsv"), val(searchengine), emit: adjusted_tsv
    path "versions.yml"                                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${psm_utils_tsv.baseName}"
    
    """
    adjust_psm_list.py \\
        -in_file ${psm_utils_tsv} \\
        -out_file ${prefix}.adjusted.tsv \\
        -searchengine ${searchengine} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${psm_utils_tsv.baseName}"
    """
    touch ${prefix}.adjusted.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
