process CONVERT_BRUKER_D {
    tag "$meta.id"
    
    label 'tdf2mzml_image'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(tdf)

    output:
    tuple val(meta), path("*.mzML"), emit: mzml
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    export MKL_NUM_THREADS=${task.cpus}
    export NUMEXPR_NUM_THREADS=${task.cpus}
    export OMP_NUM_THREADS=${task.cpus}

    tdf2mzml -i ${tdf} --compression zlib -o ${tdf.baseName}.mzML

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tdf2mzml: \$(tdf2mzml --version 2>/dev/null || echo unknown)
    END_VERSIONS
    """
}
