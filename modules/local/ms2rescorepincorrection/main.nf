process MS2RESCORE_PIN_CORRECTION {
    tag "$meta.id"
    label 'process_single'
    label 'python_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(pin_file)
    val searchengine

    output:
    tuple val(meta), path("*.corrected.pin"), emit: pin
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Convert CRLF to LF (in case there are Windows line endings)
    sed -i 's/\\r\$//' ${pin_file}

    # Correct the PIN file by moving the scan number to third column and adding correct SpecId (increasing integer)
    # This extracts the scan number from SpecId (e.g., "controllerType=0 controllerNumber=1 scan=84" -> "84")
    # and places it in ScanNr column, while replacing SpecId with sequential integers
    awk 'BEGIN {FS="\\t"; OFS="\\t"} 
         NR==1 {print; next} 
         {
             scan_nr = \$1
             gsub(/.*scan=/, "", scan_nr)
             gsub(/ .*/, "", scan_nr)
             \$3 = scan_nr
             \$1 = NR-1
             print
         }' ${pin_file} > ${prefix}.corrected.pin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version 2>&1 | head -n1 | sed 's/^GNU Awk //; s/,.*//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.corrected.pin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version 2>&1 | head -n1 | sed 's/^GNU Awk //; s/,.*//')
    END_VERSIONS
    """
}