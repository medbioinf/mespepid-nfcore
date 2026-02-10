// Original file: mspepid/src/postprocessing/convert_and_enhance_psm_tsv.nf (convert_chunked_result_to_psm_utils)
process CONVERT_TO_PSM_UTILS {
    tag "$meta.id"
    label 'process_low'
    label 'python_image'

    input:
    tuple val(meta), path(searchengine_results), val(type)

    output:
    tuple val(meta), path("${searchengine_results}.psm_utils.tsv"), emit: psm_tsv
    path "versions.yml"                                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    
    """
    convert_to_psm_utils.py \\
        -in_file ${searchengine_results} \\
        -out_file ${searchengine_results}.psm_utils.tsv \\
        -in_type ${type} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${searchengine_results}.psm_utils.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
