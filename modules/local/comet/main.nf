/*
 * Peform spectrum identification using Comet.
 */

// TODO: for now, only mzid is exported and all other outputs ignored, this should be parameterized and allow other outputs as well

process COMET {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/comet-ms:2024011--hb319eff_0'
        : 'biocontainers/comet-ms:2024011--hb319eff_0'}"

    input:
    tuple val(meta), path(mzml), path(fasta)
    val precursor_tol_ppm
    val fragment_tol_da

    output:
    tuple val(meta), path("*.mzid"), emit: mzid
    tuple val(meta), path("*.comet.params"), emit: params
    tuple val("${task.process}"), val('comet'), eval("comet | head -2 | tail -1 | sed 's;.*\"\\(.*\\).*\";\\1;g'"), topic: versions, emit: versions_comet

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def comet_threads = 8
    if (!task.cpus) {
        log.info('[Comet] Available CPUs not known - defaulting to 8. Specify the number of CPUs to change this.')
    }
    else {
        comet_threads = task.cpus.intValue()
    }

    // TODO: this should be possible to be passed
    def comet_paramfile = ""

    """
    BASE_FILENAME="${prefix}-${mzml.baseName}"
    PARAMS_FILE="${prefix}-${mzml.baseName}.comet.params"

    if [ -n "${comet_paramfile}" ]; then
        # the param file was passed, check the name
        if [ "${comet_paramfile}" != "\${PARAMS_FILE}"]; then
            # the param file has a different name than the required, so copy it to the default name for record keeping
            cp ${comet_paramfile} \${PARAMS_FILE}
        fi
    else
        # create the comet params file and change the default name
        comet -q
        mv comet.params.new \${PARAMS_FILE}
    fi

    # adjust parameters
    sed -i 's;database_name =.*;database_name = ${fasta};' \${PARAMS_FILE}

    sed -i 's;peptide_mass_tolerance_upper =.*;peptide_mass_tolerance_upper = ${precursor_tol_ppm};' \${PARAMS_FILE}
    sed -i 's;peptide_mass_tolerance_lower =.*;peptide_mass_tolerance_lower = -${precursor_tol_ppm};' \${PARAMS_FILE}
    sed -i 's;peptide_mass_units =.*;peptide_mass_units = 2;' \${PARAMS_FILE}

    sed -i 's;fragment_bin_tol =.*;fragment_bin_tol = ${fragment_tol_da};' \${PARAMS_FILE}

    sed -i "s;^num_threads.*;num_threads = ${comet_threads};" \${PARAMS_FILE}

    sed -i "s;^output_sqtfile.*;output_sqtfile = 0;" \${PARAMS_FILE}
    sed -i "s;^output_txtfile.*;output_txtfile = 0;" \${PARAMS_FILE}
    sed -i "s;^output_pepxmlfile.*;output_pepxmlfile = 0;" \${PARAMS_FILE}
    sed -i "s;^output_mzidentmlfile.*;output_mzidentmlfile = 1;" \${PARAMS_FILE}
    sed -i "s;^output_percolatorfile.*;output_percolatorfile = 0;" \${PARAMS_FILE}

    sed -i "s;^num_output_lines.*;num_output_lines = 5;" \${PARAMS_FILE}

    # run comet with given parameters
    comet \\
        ${args} \\
        -P\${PARAMS_FILE} \\
        -N\${BASE_FILENAME} \\
        ${mzml}
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}

    touch ${prefix}-${mzml.baseName}.mzid
    """
}
