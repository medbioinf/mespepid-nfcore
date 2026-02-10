process MSAMANDA_SEARCH {
    tag "$meta.id"
    label 'process_medium'
    label 'msamanda_image'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(mzml), path(fasta), path(msamanda_params)
    val precursor_tol_ppm
    val fragment_tol_da

    output:
    tuple val(meta), path("*_msamanda.csv"), emit: csv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    cp ${msamanda_params} adjusted_msamanda_settings.xml
    sed -i 's;<MS1Tol[^<]*</MS1Tol>;<MS1Tol Unit="ppm">${precursor_tol_ppm}</MS1Tol>;' adjusted_msamanda_settings.xml
    sed -i 's;<MS2Tol[^<]*</MS2Tol>;<MS2Tol Unit="Da">${fragment_tol_da}</MS2Tol>;' adjusted_msamanda_settings.xml

    # MSAmanda command line arguments:
    # Required: -s spectrumFile     single .mgf or .mzml file, or folder with multiple .mgf and .mzml files
    # Required: -d proteinDatabase  single .fasta file or folder with multiple .fasta files, which will be combined into one
    # Required: -e settings.xml
    # Optional: -f fileformat       choose 1 for .csv and 2 for .mzid, default value is 1
    # Optional: -o outputfilename   file or folder where the output should be saved, default path is location of Spectrum file

    MSAmanda -s ${mzml} -d ${fasta} -e adjusted_msamanda_settings.xml -f 1 -o ${prefix}_msamanda.csv $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msamanda: \$(MSAmanda 2>&1 | head -n 1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' || echo "3.0.22.071")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_msamanda.csv
    touch versions.yml
    """
}
