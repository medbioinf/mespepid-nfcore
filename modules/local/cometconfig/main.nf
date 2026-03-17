process COMETCONFIG {
    tag "${meta.id}"
    label 'process_single'

    publishDir path: { "${params.outdir}/comet" }, mode: params.publish_dir_mode

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/ubuntu:24.04'
        : 'nf-core/ubuntu:24.04'}"

    input:
    tuple val(meta), path(comet_config_template)
    val precursor_tol_ppm
    val fragment_tol_da

    output:
    tuple val(meta), path("*.comet.params"), emit: params

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def params_file = "${prefix}.comet.params"

    """
    if [ "${comet_config_template}" != "${params_file}" ]; then
        # the param file has a different name than the required -> copy it to the required name
        cp ${comet_config_template} ${params_file}
    fi

    # apply provided parameters (runtime settings like threads and database will be set when calling Comet)
    sed -i 's;peptide_mass_tolerance_upper =.*;peptide_mass_tolerance_upper = ${precursor_tol_ppm};' ${params_file}
    sed -i 's;peptide_mass_tolerance_lower =.*;peptide_mass_tolerance_lower = -${precursor_tol_ppm};' ${params_file}
    sed -i 's;peptide_mass_units =.*;peptide_mass_units = 2;' ${params_file}

    sed -i 's;fragment_bin_tol =.*;fragment_bin_tol = ${fragment_tol_da};' ${params_file}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def params_file = "${prefix}.comet.params"
    """
    touch ${params_file}
    """
}
