process OKTOBERFEST_TO_PIN {
    tag "$meta.id"
    label 'process_single'
    label 'oktoberfest_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(features_tsv)
    val searchengine

    output:
    tuple val(meta), path("*.oktoberfest.pin"), emit: pin
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    oktoberfest_feature_to_pin.py \\
        -in-file ${features_tsv} \\
        -out-file ${prefix}.oktoberfest.pin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        oktoberfest: \$(python -c "import oktoberfest; print(oktoberfest.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch "${prefix}.oktoberfest.pin"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        oktoberfest: \$(python -c "import oktoberfest; print(oktoberfest.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}