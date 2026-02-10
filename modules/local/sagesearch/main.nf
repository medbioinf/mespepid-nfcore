// Original file: mspepid/src/identification/sage_identification.nf (identification_with_sage)
process SAGE_SEARCH {
    tag "batch_all_mzmls"
    label 'process_high'
    label 'sage_image'

    input:
    path sage_config_file
    path fasta
    path mzmls

    output:
    path "results.sage.tsv", emit: sage_tsv
    path "versions.yml"    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def batch_size = task.ext.batch_size ?: task.cpus
    
    """
    RAYON_NUM_THREADS=${task.cpus} sage \\
        ${sage_config_file} \\
        -f ${fasta} \\
        --batch-size ${batch_size} \\
        --write-pin \\
        --output_directory ./ \\
        ${args} \\
        ${mzmls}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sage: \$(sage --version 2>&1 | sed 's/sage //g')
    END_VERSIONS
    """

    stub:
    """
    touch results.sage.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sage: \$(sage --version 2>&1 | sed 's/sage //g')
    END_VERSIONS
    """
}
