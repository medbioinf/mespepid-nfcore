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

// Original file: mspepid/src/identification/sage_identification.nf (separate_sage_results)
process SAGE_RESULTS_SEPARATE {
    tag "${sage_tsv.baseName}"
    label 'process_low'
    label 'python_image'

    publishDir "${params.outdir}/sage", mode: params.publish_dir_mode, enabled: params.publish_dir_mode != 'none'
    
    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    path sage_tsv

    output:
    path "*.sage.tsv" , emit: sage_tsv
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # process the tsv file and create one file for each input file
    # column 5 contains the filename
    for filename in \$(awk 'NR>1{a[\$5]++} END{for(b in a) print b}' ${sage_tsv});
    do
        head -n1 ${sage_tsv} > \${filename}.sage.tsv
        awk -v f1="\${filename}" '\$5==f1' ${sage_tsv} >> \${filename}.sage.tsv
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version 2>&1 | head -n1 | sed 's/GNU Awk //g' | sed 's/, .*//g')
    END_VERSIONS
    """

    stub:
    """
    touch test.mzML.sage.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        awk: \$(awk --version 2>&1 | head -n1 | sed 's/GNU Awk //g' | sed 's/, .*//g')
    END_VERSIONS
    """
}
