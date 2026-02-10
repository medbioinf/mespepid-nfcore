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

process ADJUST_MZML {
    tag "$meta.id"
    label 'process_low'
    label 'msconvert_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:// TODO nf-core: Where applicable all sample-specific information e.g. "id", "single_end", "read_group"
    //               MUST be provided as an input via a Groovy Map called "meta".
    //               This information may not be required in some instances e.g. indexing reference genome files:
    //               https://github.com/nf-core/modules/blob/master/modules/nf-core/bwa/index/main.nf
    // TODO nf-core: Where applicable please provide/convert compressed files as input/output
    //               e.g. "*.fastq.gz" and NOT "*.fastq", "*.bam" and NOT "*.sam" etc.
    tuple val(meta), path(mzml)

    output:
    // TODO nf-core: Named file extensions MUST be emitted for ALL output channels
    tuple val(meta), path("uncompressed/*.mzML"), emit: mzml
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when
    
    script:
    """
    sed -e 's/<spectrum\\(.*\\) id="index=\\([0-9]*\\)\\(.*\\)/<spectrum\\1 id="index=\\2 scan=\\2\\3/; \
            s/spectrumRef="\\(.*\\)index=\\([0-9]*\\)\\(.*\\)"/spectrumRef="\\1index=\\2 scan=\\2\\3"/' \
        ${mzml} > ${mzml.baseName}.reindex.mzML

    mkdir -p uncompressed
    wine msconvert --mzML --zlib=off \
        -o uncompressed \
        --outfile ${mzml.baseName}.mzML \
        ${mzml.baseName}.reindex.mzML

    rm ${mzml.baseName}.reindex.mzML

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msconvert: \$(wine msconvert --version 2>/dev/null | head -n 1 || echo unknown)
    END_VERSIONS
    """
}
