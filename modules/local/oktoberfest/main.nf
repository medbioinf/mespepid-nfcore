process OKTOBERFEST {
    tag "$meta.id"
    label 'process_high'
    label 'oktoberfest_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"
    
    input:
    tuple val(meta), path(psm_tsv), path(spectra_file)
    val searchengine
    val scan_id_pattern
    val fragment_tol_da
    val oktoberfest_intensity_model
    val oktoberfest_irt_model

    output:
    tuple val(meta), path("*.oktoberfest.tsv"), emit: features
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    oktoberfest_feature_gen.py \\
        -out-folder ./oktoberfest_out \\
        -psms-file ${psm_tsv} \\
        -spectra-file ${spectra_file} \\
        -intensity-model ${oktoberfest_intensity_model} \\
        -irt-model ${oktoberfest_irt_model} \\
        -mass-tolerance ${fragment_tol_da} \\
        -mass-tolerance-unit da \\
        -scan-id-regex '${scan_id_pattern}'

    mv ./oktoberfest_out/results/none/rescore.tab "${prefix}.oktoberfest.tsv"

    # Clean up the output directory
    rm -r oktoberfest_out

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        oktoberfest: \$(python -c "import oktoberfest; print(oktoberfest.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch "${prefix}.oktoberfest.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        oktoberfest: \$(python -c "import oktoberfest; print(oktoberfest.__version__)" 2>/dev/null || echo "unknown")
    END_VERSIONS
    """
}