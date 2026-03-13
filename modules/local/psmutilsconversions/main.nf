// TODO: here, or rather in adjust_psm_list.py, the modifications must be fixed!

process PSMUTILSCONVERSIONS {
    tag "${meta.id}"

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE'
        : 'quay.io/medbioinf/psm-utils:pepxml-and-mzid-fixes'}"

    input:
    tuple val(meta), path(identifications)

    output:
    tuple val(meta), path("*.psm_utils.tsv"), emit: psm_utils_tsv
    tuple val(meta), path("*.pin"), emit: pin

    tuple val("${task.process}"), val('psm-utils'), val('pepxml-and-mzid-fixes'), topic: versions, emit: versions_psm_utils
    tuple val("${task.process}"), val('Python'), eval('python3 --version | sed "s/Python //"'), topic: versions, emit: versions_python

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def searchengine = meta.searchengine ?: 'unknown'
    def idfile_type = meta.idfile_type ?: 'unknown'

    """
    convert_to_psm_utils.py \\
            -in_file ${identifications} \\
            -out_file psm_utils.tsv \\
            -in_type ${idfile_type} \\
            ${args}

    adjust_psm_list.py \\
            -in_file psm_utils.tsv \\
            -out_file adjusted.tsv \\
            -searchengine ${searchengine} \\
            ${args}

    psms_to_pin_and_enhancedTSV.py \\
            -in_file adjusted.tsv \\
            -out_file ${prefix}.psm_utils.tsv \\
            -out_pin percolator.pre \\
            -use_only_rank1_psms true \\
            -searchengine ${searchengine} \\
            ${args}

    # correct the PIN file by moving the scan number to third column and adding correct SpecId (increasing integer)
    awk '{FS="\t";OFS="\t"; if (NR>1) { \$3=\$1; \$1=NR-1; gsub(".*=", "", \$3) } print}' percolator.pre > ${prefix}.pin
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo ${args}

    touch ${prefix}.psm_utils.tsv
    touch ${prefix}.pin
    """
}
