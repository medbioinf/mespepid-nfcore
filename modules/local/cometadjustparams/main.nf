process COMET_ADJUST_PARAMS {
    tag "$meta.id"
    label 'process_low'
    label 'python_image'


    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(comet_params)
    val precursor_tol_ppm
    val fragment_tol_da

    output:
    tuple val(meta), path("*.params"), emit: params
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def comet_threads = task.ext.comet_threads ?: task.cpus
    """
    cp ${comet_params} ${prefix}.params
    
    # Set precursor mass tolerance
    sed -i 's;peptide_mass_tolerance_upper =.*;peptide_mass_tolerance_upper = ${precursor_tol_ppm};' ${prefix}.params
    sed -i 's;peptide_mass_tolerance_lower =.*;peptide_mass_tolerance_lower = -${precursor_tol_ppm};' ${prefix}.params
    sed -i 's;peptide_mass_units =.*;peptide_mass_units = 2;' ${prefix}.params

    # Set fragment mass tolerance
    sed -i 's;fragment_bin_tol =.*;fragment_bin_tol = ${fragment_tol_da};' ${prefix}.params
    
    # Set number of threads
    sed -i "s;^num_threads.*;num_threads = ${comet_threads};" ${prefix}.params

    # Configure output formats
    sed -i "s;^output_sqtfile.*;output_sqtfile = 0;" ${prefix}.params
    sed -i "s;^output_txtfile.*;output_txtfile = 0;" ${prefix}.params
    sed -i "s;^output_pepxmlfile.*;output_pepxmlfile = 0;" ${prefix}.params
    sed -i "s;^output_mzidentmlfile.*;output_mzidentmlfile = 1;" ${prefix}.params
    sed -i "s;^output_percolatorfile.*;output_percolatorfile = 0;" ${prefix}.params
    
    # Set number of output lines
    sed -i "s;^num_output_lines.*;num_output_lines = 5;" ${prefix}.params
    $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(sed --version 2>&1 | head -n 1 | sed 's/sed (GNU sed) //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.params
    """
}
