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

// Original file: mspepid/src/identification/sage_identification.nf (adjust_sage_config)
process SAGE_ADJUST_CONFIG {
    tag "${default_config_file.baseName}"
    label 'process_low'
    label 'python_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    path default_config_file
    val precursor_tol_ppm
    val fragment_tol_da

    output:
    path "adjusted_sage_config.json", emit: config
    path "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefilter_chunk_size = task.ext.prefilter_chunk_size ?: 100000
    def prefilter = task.ext.prefilter != null ? task.ext.prefilter : true
    
    """
    python <<CODE
import json

# Opening JSON file
with open("${default_config_file}", 'r') as openfile:
    # Reading from json file
    json_object = json.load(openfile)

# adjust the tolerances
json_object["precursor_tol"] = {'ppm': [-${precursor_tol_ppm}, ${precursor_tol_ppm}]}
json_object["fragment_tol"] = {'da': [-${fragment_tol_da}, ${fragment_tol_da}]}

# adjust database prefilter
json_object["database"]["prefilter_chunk_size"] = ${prefilter_chunk_size}
json_object["database"]["prefilter"] = (str("${prefilter}").strip().lower() == "true")
json_object["database"]["prefilter_low_memory"] = False

# Writing to adjusted_sage_config.json
with open("./adjusted_sage_config.json", "w") as outfile:
    json.dump(json_object, outfile)
CODE

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    python: \$(python --version 2>&1 | sed 's/Python //g')
END_VERSIONS
    """

    stub:
    """
    touch adjusted_sage_config.json

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    python: \$(python --version 2>&1 | sed 's/Python //g')
END_VERSIONS
    """
}
