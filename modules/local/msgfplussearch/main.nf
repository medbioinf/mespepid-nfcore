process MSGFPLUS_SEARCH {
    tag "$meta.id"
    label 'process_medium'
    label 'msgfplus_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"
        
    input:
    tuple val(meta), path(msgfplus_params), path(mzml), path(fasta), path(canno), path(cnlcp), path(csarr), path(cseq), val(precursor_tol_ppm)

    output:
    tuple val(meta), path("${mzml.baseName}*.mzid"), emit: mzid
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def instrument = task.ext.instrument ?: '0'
    def threads = task.cpus
    def tasks_param = task.ext.tasks ?: threads
    def mem_gb = task.memory ? task.memory.toGiga() : 8
    
    """
    cp ${msgfplus_params} adjusted_MSGFPlus_Params.txt
    sed -i 's;^PrecursorMassTolerance=.*;PrecursorMassTolerance=${precursor_tol_ppm};' adjusted_MSGFPlus_Params.txt
    sed -i 's;^InstrumentID=.*;InstrumentID=${instrument};' adjusted_MSGFPlus_Params.txt

    java -Xmx${mem_gb}G -jar /opt/msgfplus/MSGFPlus.jar \\
        -conf adjusted_MSGFPlus_Params.txt \\
        -s ${mzml} \\
        -d ${fasta} \\
        -thread ${threads} \\
        -tasks ${tasks_param} \\
        -o ${mzml.baseName}.mzid \\
        ${args}

    if [[ ${fasta} == *"-split"* ]]; then
        splitnum=\$(echo "${fasta}" | sed "s;.*-split-\\([0-9]*\\).fasta;\\1;")
        echo "renaming ${mzml.baseName}.mzid to ${mzml.baseName}-split-\${splitnum}.mzid"
        mv ${mzml.baseName}.mzid ${mzml.baseName}-split-\${splitnum}.mzid
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msgfplus: \$(java -jar /opt/msgfplus/MSGFPlus.jar 2>&1 | grep -oP 'MS-GF\\+ \\(v\\K[0-9.]+' || echo "unknown")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.mzid

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msgfplus: unknown
    END_VERSIONS
    """
}
