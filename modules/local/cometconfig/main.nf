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

    // TODO: this kind of parameters shoudl not be used, use as an input variable instead
    def output_sqt = task.ext.output_sqt == null ? 0 : (task.ext.output_sqt ? 1 : 0)
    def output_txt = task.ext.output_txt == null ? 0 : (task.ext.output_txt ? 1 : 0)
    def output_pepxml = task.ext.output_pepxml == null ? 0 : (task.ext.output_pepxml ? 1 : 0)
    def output_mzidentml = task.ext.output_mzidentml == null ? 1 : (task.ext.output_mzidentml ? 1 : 0)
    def output_percolator = task.ext.output_percolator == null ? 0 : (task.ext.output_percolator ? 1 : 0)
    def num_output_lines = task.ext.num_output_lines == null ? 5 : task.ext.num_output_lines

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

    # set the output parameters
    sed -i "s;^output_sqtfile.*;output_sqtfile = ${output_sqt};" ${params_file}
    sed -i "s;^output_txtfile.*;output_txtfile = ${output_txt};" ${params_file}
    sed -i "s;^output_pepxmlfile.*;output_pepxmlfile =  ${output_pepxml};" ${params_file}
    sed -i "s;^output_mzidentmlfile.*;output_mzidentmlfile = ${output_mzidentml};" ${params_file}
    sed -i "s;^output_percolatorfile.*;output_percolatorfile = ${output_percolator};" ${params_file}

    sed -i "s;^num_output_lines.*;num_output_lines = ${num_output_lines};" ${params_file}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def params_file = "${prefix}.comet.params"
    """
    touch ${params_file}
    """
}
