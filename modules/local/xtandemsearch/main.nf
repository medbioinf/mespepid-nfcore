// Original file: mspepid/src/identification/xtandem_identification.nf (identification_with_xtandem)
process XTANDEM_SEARCH {
    tag "${meta.id}"
    label 'process_high'
    label 'xtandem_image'
    
    publishDir "${params.outdir}/xtandem", mode: 'copy'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(xtandem_param_file), path(mzml), path(taxonomy_file), path(fasta)

    output:
    tuple val(meta), path("*.t.xml"), emit: xml
    path "versions.yml"             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    tandem ${xtandem_param_file} ${args}

    # Get version, handling potential errors
    VERSION=\$(tandem --version 2>/dev/null | head -n1 | sed 's/.*X! Tandem //' || true)
    [ -z "\$VERSION" ] && VERSION="unknown"

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    xtandem: "\${VERSION}"
END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.xtandem_identification.t.xml

    VERSION=\$(tandem --version 2>/dev/null | head -n1 | sed 's/.*X! Tandem //' || true)
    [ -z "\$VERSION" ] && VERSION="unknown"

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    xtandem: "\${VERSION}"
END_VERSIONS
    """
}
