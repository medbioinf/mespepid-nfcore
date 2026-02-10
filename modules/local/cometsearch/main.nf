process COMET_SEARCH {
    tag "$meta.id"
    label 'process_high'
    label 'comet_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(mzml), path(fasta), path(comet_params)

    output:
    tuple val(meta), path("*.mzid"), emit: mzid
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    comet \\
        -P${comet_params} \\
        -D${fasta} \\
        ${mzml} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        comet: \$(comet 2>&1 | grep -E "Comet version.*" | sed 's/Comet version //g' | sed 's/\"//g' | head -n 1)
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.mzid
    """
}
