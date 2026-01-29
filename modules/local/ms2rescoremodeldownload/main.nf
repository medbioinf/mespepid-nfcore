process MS2RESCORE_MODEL_DOWNLOAD {
    tag "${ms2rescore_model}"
    label 'process_low'
    label 'python_image'

    maxForks 1  // Ensure download happens only once

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    val ms2rescore_model
    val model_dir

    output:
    val model_dir           , emit: model_dir
    path "versions.yml"     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    mkdir -p "${model_dir}"

    ms2rescore_check_or_download_model.py \\
        -ms2pip_model ${ms2rescore_model} \\
        -model_dir "${model_dir}"
    
    chmod -R 777 "${model_dir}"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        ms2rescore: \$(python -c "import ms2rescore; print(ms2rescore.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    mkdir -p "${model_dir}"
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        ms2rescore: \$(python -c "import ms2rescore; print(ms2rescore.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}
