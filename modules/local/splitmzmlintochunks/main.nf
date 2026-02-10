process SPLIT_MZML_INTO_CHUNKS {
    tag "$meta.id"
    label 'process_low'
    label 'msconvert_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(mzml)
    val chunksize

    output:
    tuple val(meta), path("${mzml.baseName}--*.mzML"), emit: mzml_chunks
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

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
