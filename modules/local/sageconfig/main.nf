/*
 * Adjust the default Sage config with the given search params
 *
 * Attention: Version is not etermind by `eval`, as it is only available with bash process script not with interpreter (#!/usr/bin/env python/)
 **/

process SAGECONFIG {
    tag "${precursor_tol_ppm}ppm_${fragment_tol_da}da_sage_config"
    label 'process_single'

    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE'
        : 'biocontainers/python:3.14'}"

    input:
    path config_template
    val prefilter_chunk_size
    val prefilter
    val precursor_tol_ppm
    val fragment_tol_da

    output:
    path ("adjusted.sage.json"), emit: config
    tuple val("${task.process}"), val('Python'), val("3.14.3"), topic: versions, emit: versions_sageconfig

    when:
    task.ext.when == null || task.ext.when

    script:
    """
#!/usr/bin/env python
import json

# Opening JSON file
with open("${config_template}", 'r') as openfile:
    # Reading from json file
    json_object = json.load(openfile)

# adjust the tolerances
json_object["precursor_tol"] = {'ppm': [-${precursor_tol_ppm}, ${precursor_tol_ppm}]}
json_object["fragment_tol"] = {'da': [-${fragment_tol_da}, ${fragment_tol_da}]}

# adjust database prefilter
json_object["database"]["prefilter_chunk_size"] = ${prefilter_chunk_size}
json_object["database"]["prefilter"] = (str("${prefilter}").strip().lower() == "true")
json_object["database"]["prefilter_low_memory"] = False

# Writing to sample.json
with open("./adjusted.sage.json", "w") as outfile:
    json.dump(json_object, outfile)
    """

    stub:
    def args = task.ext.args ?: ''

    """
    echo ${args}

    touch adjusted.sage.json
    """
}
