process MS2RESCORE {
    tag "$meta.id"
    label 'process_high'
    label 'python_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(psm_tsv), path(spectra_file)
    val searchengine
    val spectrum_id_pattern
    val fragment_tol_da
    val ms2rescore_model
    val ms2rescore_chunk_size
    val model_dir

    output:
    tuple val(meta), path("*.ms2rescore.pin"), emit: pin
    path "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    chunked_ms2rescore.py \\
        -psms_file ${psm_tsv} \\
        -spectra ${spectra_file} \\
        -model ${ms2rescore_model} \\
        -model_dir "${model_dir}" \\
        -ms2_tolerance ${fragment_tol_da} \\
        -spectrum_id_pattern '${spectrum_id_pattern}' \\
        -processes ${task.cpus} \\
        -chunk_size ${ms2rescore_chunk_size} \\
        -out_file "${prefix}.ms2rescore.pin" \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        ms2rescore: \$(python -c "import ms2rescore; print(ms2rescore.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.ms2rescore.pin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        ms2rescore: \$(python -c "import ms2rescore; print(ms2rescore.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}