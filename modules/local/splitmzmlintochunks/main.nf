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

process SPLIT_MZML_INTO_CHUNKS {
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
    val chunksize

    output:
    tuple val(meta), path("${mzml.baseName}--*.mzML"), emit: mzml_chunks
    path "versions.yml", emit: versions

    script:
    """
    CHUNKSIZE=${chunksize}

    # Extract only MS2 spectra
    wine msconvert --mzML \
        --filter "msLevel 2-" \
        "${mzml}" \
        --outfile "${mzml.baseName}-MS2only.mzML"

    # Determine last spectrum index
    MAX_INDEX=\$(tac "${mzml.baseName}-MS2only.mzML" \
        | grep -m1 "<spectrum.*index=" \
        | sed 's;.*index="\\([0-9]*\\)".*;\\1;')

    echo "Max index: \${MAX_INDEX}"

    for ((i=0; i<=MAX_INDEX; i+=CHUNKSIZE)); do
        START_INDEX=\$i
        END_INDEX=\$((i+CHUNKSIZE-1))
        if ((END_INDEX > MAX_INDEX)); then
            END_INDEX=\$MAX_INDEX
        fi
        echo "Processing spectra from index \${START_INDEX} to \${END_INDEX}"

        wine msconvert --mzML \
            --filter "index [\${START_INDEX},\${END_INDEX}]" \
            "${mzml.baseName}-MS2only.mzML" \
            --outfile "${mzml.baseName}--\${START_INDEX}_\${END_INDEX}.mzML"
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        msconvert: \$(wine msconvert --version 2>/dev/null | head -n 1 || echo unknown)
    END_VERSIONS
    """
}
