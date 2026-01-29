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
