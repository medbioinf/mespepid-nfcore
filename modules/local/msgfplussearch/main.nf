// TODO nf-core: If in doubt look at other nf-core/modules to see how we are doing things! :)
//               https://github.com/nf-core/modules/tree/master/modules/nf-core/
//               You can also ask for help via your pull request or on the #modules channel on the nf-core Slack workspace:
//               https://nf-co.re/join
// TODO nf-core: A module file SHOULD only define input and output files as command-line parameters.
//               All other parameters MUST be provided using the "task.ext" directive, see here:
//               https://www.nextflow.io/docs/latest/process.html#ext
//               where "task.ext" is a string.
//               Any parameters that need to be evaluated in the context of a particular sample
//               e.g. single-end/paired-end data MUST also be defined and evaluated appropriately.
// TODO nf-core: Software that can be piped together SHOULD be added to separate module files
//               unless there is a run-time, storage advantage in implementing in this way
//               e.g. it's ok to have a single module for bwa to output BAM instead of SAM:
//                 bwa mem | samtools view -B -T ref.fasta
// TODO nf-core: Optional inputs are not currently supported by Nextflow. However, using an empty
//               list (`[]`) instead of a file can be used to work around this issue.

process MSGFPLUS_SEARCH {
    tag "$meta.id"
    label 'process_medium'
    label 'msgfplus_image'

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
