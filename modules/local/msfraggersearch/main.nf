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

process MSFRAGGER_SEARCH {
    tag "$meta.id"
    label 'process_medium'
    label 'msfragger_image'

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(mzml), path(fasta), path(adjusted_params)

    output:
    tuple val(meta), path("*.pepXML"), emit: pepxml
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    """
    java -Xmx${task.memory.toGiga()}G -jar /home/mambauser/MSFragger-4.2/MSFragger-4.2.jar ${adjusted_params} ${mzml} $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msfragger: \$(java -jar /home/mambauser/MSFragger-4.2/MSFragger-4.2.jar --version 2>&1 | grep -oE 'MSFragger-[0-9]+\\.[0-9]+' | sed 's/MSFragger-//' || echo "4.2")
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pepXML
    touch versions.yml
    """
}
