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

// Original file: mspepid/src/postprocessing/convert_and_enhance_psm_tsv.nf (enhance_psms_and_create_pin - psms_to_pin_and_enhancedTSV.py part)
process PSMS_TO_PIN_AND_ENHANCED_TSV {
    tag "$meta.id"
    label 'process_low'
    label 'python_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    publishDir "${params.outdir}/${searchengine}", mode: params.publish_dir_mode, enabled: params.publish_dir_mode != 'none'

    input:
    tuple val(meta), path(adjusted_tsv), val(searchengine)

    output:
    tuple val(meta), path("*.enhanced.tsv"), emit: psm_tsv
    tuple val(meta), path("*.pin")         , emit: pin_file
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${adjusted_tsv.baseName}"
    def use_only_rank1 = task.ext.use_only_rank1_psms != null ? task.ext.use_only_rank1_psms : true
    
    """
    psms_to_pin_and_enhancedTSV.py \\
        -in_file ${adjusted_tsv} \\
        -out_file ${prefix}.enhanced.tsv \\
        -out_pin ${prefix}.pre.pin \\
        -use_only_rank1_psms ${use_only_rank1} \\
        -searchengine ${searchengine} \\
        ${args}

    # correct the PIN file by moving the scan number to third column and adding correct SpecId (increasing integer)
    awk '{FS="\t";OFS="\t"; if (NR>1) { \$3=\$1; \$1=NR-1; gsub(".*=", "", \$3) } print}' ${prefix}.pre.pin > ${prefix}.pin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${adjusted_tsv.baseName}"
    """
    touch ${prefix}.enhanced.tsv
    touch ${prefix}.pin

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
