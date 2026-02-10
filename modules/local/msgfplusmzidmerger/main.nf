process MSGFPLUS_MZID_MERGER {
    tag "$meta.id"
    label 'process_low'
    label 'mzidmerger_image'
    
    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), val(mzml_split), path(mzid_files)

    output:
    tuple val(meta), path("${mzml_split}.mzid"), emit: mzid
    path "versions.yml"                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    
    """
    mono /home/mambauser/mzidmerger/MzidMerger.exe \\
        -InDir "./" \\
        -Filter "*.mzid" \\
        -Out ${mzml_split}.merged.mzid \\
        ${args}
    
    mv ${mzml_split}.merged.mzid ${mzml_split}.mzid

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mzidmerger: \$(mono /home/mambauser/mzidmerger/MzidMerger.exe 2>&1 | grep -oP 'version \\K[0-9.]+' || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch ${mzml_split}.mzid

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mzidmerger: unknown
    END_VERSIONS
    """
}
