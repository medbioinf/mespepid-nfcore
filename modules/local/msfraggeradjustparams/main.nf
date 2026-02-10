process MSFRAGGER_ADJUST_PARAMS {
    tag "$meta.id"
    label 'process_low'
    label 'python_image'

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(msfragger_params)
    path fasta
    val precursor_tol_ppm
    val fragment_tol_da

    output:
    tuple val(meta), path("*_adjusted_fragger.params"), emit: params
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    cp ${msfragger_params} ${prefix}_adjusted_fragger.params

    sed -i "s;^database_name.*;database_name = ${fasta};" ${prefix}_adjusted_fragger.params
    sed -i "s;^num_threads.*;num_threads = ${task.cpus};" ${prefix}_adjusted_fragger.params

    sed -i 's;precursor_mass_lower =.*;precursor_mass_lower = -${precursor_tol_ppm};' ${prefix}_adjusted_fragger.params
    sed -i 's;precursor_mass_upper =.*;precursor_mass_upper = ${precursor_tol_ppm};' ${prefix}_adjusted_fragger.params
    sed -i 's;precursor_mass_units =.*;precursor_mass_units = 1;' ${prefix}_adjusted_fragger.params

    sed -i 's;fragment_mass_tolerance =.*;fragment_mass_tolerance = ${fragment_tol_da};' ${prefix}_adjusted_fragger.params
    sed -i 's;fragment_mass_units =.*;fragment_mass_units = 0;' ${prefix}_adjusted_fragger.params

    sed -i "s;^decoy_prefix.*;decoy_prefix = DECOY_;" ${prefix}_adjusted_fragger.params

    sed -i "s;^output_format.*;output_format = pepxml;" ${prefix}_adjusted_fragger.params
    
    sed -i "s;^output_report_topN.*;output_report_topN = 5;" ${prefix}_adjusted_fragger.params

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(sed --version 2>&1 | head -n 1 | sed 's/.*) //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_adjusted_fragger.params
    touch versions.yml
    """
}
