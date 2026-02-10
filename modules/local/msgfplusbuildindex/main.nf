process MSGFPLUS_BUILD_INDEX {
    tag "$fasta.baseName"
    label 'process_medium'
    label 'msgfplus_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    path fasta

    output:
    tuple path("${fasta}"), path("${fasta.baseName}.canno"), path("${fasta.baseName}.cnlcp"), path("${fasta.baseName}.csarr"), path("${fasta.baseName}.cseq"), emit: index
    path "versions.yml"                                                                                                                                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def mem_gb = task.memory ? task.memory.toGiga() : 8
    
    """
    java -Xmx${mem_gb}G -cp /opt/msgfplus/MSGFPlus.jar \\
        edu.ucsd.msjava.msdbsearch.BuildSA \\
        -d ${fasta} \\
        -tda 0 \\
        -o ./ \\
        -decoy DECOY_ \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msgfplus: \$(java -jar /opt/msgfplus/MSGFPlus.jar 2>&1 | grep -oP 'MS-GF\\+ \\(v\\K[0-9.]+' || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch ${fasta.baseName}.canno
    touch ${fasta.baseName}.cnlcp
    touch ${fasta.baseName}.csarr
    touch ${fasta.baseName}.cseq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msgfplus: unknown
    END_VERSIONS
    """
}
