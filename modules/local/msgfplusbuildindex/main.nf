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

process MSGFPLUS_BUILD_INDEX {
    tag "$fasta.baseName"
    label 'process_medium'
    label 'msgfplus_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    path fasta

    output:
    tuple path("${fasta}"), path("${fasta.baseName}.canno"), path("${fasta.baseName}.cnlcp"), path("${fasta.baseName}.csarr"), path("${fasta.baseName}.cseq"), emit: index
    path "versions.yml"                                                                                                                                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def mem_gb = task.memory ? task.memory.toGiga() : 8
    
    """
    java -Xmx${mem_gb}G -cp /opt/msgfplus/MSGFPlus.jar \\
        edu.ucsd.msjava.msdbsearch.BuildSA \\
        -d ${fasta} \\
        -tda 0 \\
        -o ./ \\
        -decoy DECOY_ \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msgfplus: \$(java -jar /opt/msgfplus/MSGFPlus.jar 2>&1 | grep -oP 'MS-GF\\+ \\(v\\K[0-9.]+' || echo "unknown")
    END_VERSIONS
    """

    stub:
    """
    touch ${fasta.baseName}.canno
    touch ${fasta.baseName}.cnlcp
    touch ${fasta.baseName}.csarr
    touch ${fasta.baseName}.cseq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msgfplus: unknown
    END_VERSIONS
    """
}
