process MSFRAGGER_SEARCH {
    tag "$meta.id"
    label 'process_medium'
    label 'msfragger_image'

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(mzml), path(fasta), path(adjusted_params)

    output:
    tuple val(meta), path("*.pepXML"), emit: pepxml
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    java -Xmx${task.memory.toGiga()}G -jar /home/mambauser/MSFragger-4.2/MSFragger-4.2.jar ${adjusted_params} ${mzml} $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msfragger: \$(java -jar /home/mambauser/MSFragger-4.2/MSFragger-4.2.jar --version 2>&1 | grep -oE 'MSFragger-[0-9]+\\.[0-9]+' | sed 's/MSFragger-//' || echo "4.2")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pepXML
    touch versions.yml
    """
}
