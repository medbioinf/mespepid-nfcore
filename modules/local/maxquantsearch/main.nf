process MAXQUANT_SEARCH {
    tag "$meta.id"
    label 'process_high'
    label 'maxquant_image'

    maxRetries 0  // Disable retries to prevent memory doubling beyond available memory
    stageInMode 'copy'  // MaxQuant/Mono does not support symlinks

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(spectra_file), path(maxquant_params)

    output:
    tuple val(meta), path("*_msms.txt"), emit: msms
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Execute MaxQuant identification with pre-adjusted parameters
    dotnet /opt/MaxQuant/bin/MaxQuantCmd.dll ${maxquant_params}
    $args

    # Extract the spectra file path from the XML <filePaths> section and get its directory
    SPECTRA_PATH=\$(grep -A1 '<filePaths>' ${maxquant_params} | grep -oP '<string>\\K[^<]+')
    SPECTRA_DIR=\$(dirname "\$SPECTRA_PATH")

    # MaxQuant writes output to the directory where the input file is located
    # Output is typically in combined/txt/ directory
    cp "\${SPECTRA_DIR}/combined/txt/msms.txt" ${prefix}_msms.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        maxquant: \$(dotnet /opt/MaxQuant/bin/MaxQuantCmd.dll --version 2>&1 | grep -oP 'MaxQuant version \\K[0-9.]+' || echo "2.6.7.0")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_msms.txt
    touch versions.yml
    """
}
