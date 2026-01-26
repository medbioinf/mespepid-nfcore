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

process CALLENTRAPMENTDATABASE {
    label 'process_single'
    label 'fdrbench_image'

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
    path fasta
    val fold

    output:
    // TODO nf-core: Named file extensions MUST be emitted for ALL output channels
    path "*.fasta", emit: fasta
    path "versions.yml", emit: versions

    // when:
    // task.ext.when == null || task.ext.when

    script:
    """
    # Convert Nextflow memory object to GB for Java
    MEM_GB=\$(( ${task.memory.toGiga()} ))

    java -Xmx\${MEM_GB}G \
        -jar /opt/fdrbench/fdrbench.jar \
        -db ${fasta} \
        -o ${fasta.baseName}-entrapment.fasta \
        -fold ${fold} \
        -level protein \
        -entrapment_label ENTRAPMENT_ \
        -entrapment_pos 0 \
        -uniprot \
        -check

    # 'Reheader' to add entrapment index to database and accession part of the header
    # and remove empty entrapment sequences (which can appear if the original sequence has many Xs)
    # The following sed command performs two operations:
    # 1. Substitutes FASTA headers to include the entrapment index in both the database and accession parts.
    #    Regex breakdown:
    #      ^>ENTRAPMENT_(.+)\\|(.+)\\|(.+)_([0-9]+)\$
    #        - Matches headers starting with '>ENTRAPMENT_' followed by three fields separated by '|', with the last field ending in '_[number]'.
    #      >ENTRAPMENT_\\4_\\1|ENTRAPMENT_\\4_\\2|\\3_\\4
    #        - Rewrites the header to include the entrapment index (\\4) in both the database and accession parts.
    # 2. Removes empty entrapment sequences (headers followed by an empty line).
    #    Control flow:
    #      \$!N;/>.*\\n\$/d;P;D
    #        - Reads two lines at a time; if a header is followed by an empty line, deletes both.

    sed -r -i \
        -e "s;^>ENTRAPMENT_(.+)\\|(.+)\\|(.+)_([0-9]+)\$;>ENTRAPMENT_\\4_\\1|ENTRAPMENT_\\4_\\2|\\3_\\4;g" \
        -e '\$!N;/>.*\\n\$/d;P;D' \
        ${fasta.baseName}-entrapment.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fdrbench: \$(java -jar /opt/fdrbench/fdrbench.jar --version 2>/dev/null || echo unknown)
    END_VERSIONS
    """
}
