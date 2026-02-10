process PERCOLATOR {
    tag "$meta.id"
    label 'process_medium'
    label 'percolator_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(pin_file)
    val searchengine

    output:
    tuple val(meta), path("*.pout"), emit: pout
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    percolator \\
        --num-threads ${task.cpus} \\
        --only-psms \\
        --post-processing-tdc \\
        --search-input concatenated \\
        --results-psms ${prefix}.pout \\
        ${args} \\
        ${pin_file}

    VERSION=\$(percolator --version 2>/dev/null | head -n1 | sed 's/Percolator version //' || true)
    [ -z "\$VERSION" ] && VERSION="unknown"

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    percolator: "\${VERSION}"
END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pout

    VERSION=\$(percolator --version 2>/dev/null | head -n1 | sed 's/Percolator version //' || true)
    [ -z "\$VERSION" ] && VERSION="unknown"

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    percolator: "\${VERSION}"
END_VERSIONS
    """
}